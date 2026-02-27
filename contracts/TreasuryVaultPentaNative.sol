// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * PentaChain - Native Treasury Vault (Native Coin only)
 *
 * Features / Hardening:
 * - Feste Budgets (Staking, Airdrop, Listings, Future) als harte Caps in Wei
 * - Queue -> Timelock -> Execute (mit minDelay); execute funktioniert auch im Pause-Status (um Deadlocks zu vermeiden)
 * - Pause/Guardian: Owner kann pausieren, Guardian kann entpausieren
 * - Optionales Whitelisting für Staking/Airdrop-Targets + Freezable (irreversibel)
 * - ReentrancyGuard für executeQueued
 * - Keine Backdoors: kein Upgrade, kein selfdestruct, KEIN rescueNative (um Budget-Caps nicht zu umgehen)
 * - Nur native PENTA (Chain Coin); akzeptiert Einzahlungen via receive()
 * - Optional: rescueForeignERC20 für versehentlich gesendete ERC20 (kein Zugriff auf natives PENTA)
 */

interface IERC20Minimal {
    function transfer(address to, uint256 value) external returns (bool);
}

abstract contract Ownable {
    address public owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    modifier onlyOwner() { require(msg.sender == owner, "Not owner"); _; }

    constructor(address _owner) {
        require(_owner != address(0), "owner=0");
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "newOwner=0");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;
    modifier nonReentrant() {
        require(_status != _ENTERED, "reentrancy");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract TreasuryVaultPentaNative is Ownable, ReentrancyGuard {
    // ===== Buckets & Budgets (Wei) =====
    enum Bucket { Staking, Airdrop, Listings, Future }

    uint256 public constant BUDGET_STAKING  = 80_000_000 ether;  // 80M * 1e18
    uint256 public constant BUDGET_AIRDROP  = 40_000_000 ether;  // 40M * 1e18
    uint256 public constant BUDGET_LISTINGS = 30_000_000 ether;  // 30M * 1e18
    uint256 public constant BUDGET_FUTURE   = 19_000_000 ether;  // 19M * 1e18

    mapping(Bucket => uint256) public spent; // bereits ausgezahlt (Wei)

    // ===== Optional: Ziel-Bindungen + Freeze =====
    address public stakingTarget;
    address public airdropTarget;
    bool    public stakingTargetFrozen;
    bool    public airdropTargetFrozen;

    // ===== Pause / Guardian =====
    bool public paused;
    address public guardian; // darf immer entpausieren
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event GuardianSet(address indexed guardian);

    // ===== Timelock Queue =====
    struct Withdrawal {
        uint256 id;
        Bucket  bucket;
        address to;
        uint256 amount;     // Wei
        string  reason;
        uint64  eta;        // earliest execute timestamp
        bool    executed;
        bool    canceled;
    }
    uint256 public nextWithdrawalId = 1;
    uint256 public minDelay; // Sekunden
    mapping(uint256 => Withdrawal) public queue;

    event MinDelaySet(uint256 newDelay);
    event Queued(
        uint256 indexed id,
        Bucket indexed bucket,
        address indexed to,
        uint256 amount,
        string reason,
        uint64 eta,
        address caller
    );
    event Executed(uint256 indexed id, address indexed executor);
    event Canceled(uint256 indexed id, address indexed caller);

    // ===== Target Events =====
    event StakingTargetSet(address indexed target, bool frozen);
    event AirdropTargetSet(address indexed target, bool frozen);

    // ===== Funds Events =====
    event FundsReceived(address indexed from, uint256 amount);

    // ===== Constructor =====
    constructor(
        address _owner,
        address _guardian,
        uint256 _minDelaySeconds,
        address _initialStakingTarget, // optional (0x0 erlaubt)
        address _initialAirdropTarget  // optional (0x0 erlaubt)
    ) Ownable(_owner) {
        guardian  = _guardian;
        emit GuardianSet(_guardian);

        require(_minDelaySeconds >= 1 hours && _minDelaySeconds <= 30 days, "minDelay out of range");
        minDelay = _minDelaySeconds;
        emit MinDelaySet(minDelay);

        stakingTarget = _initialStakingTarget;
        airdropTarget = _initialAirdropTarget;

        emit StakingTargetSet(stakingTarget, false);
        emit AirdropTargetSet(airdropTarget, false);
    }

    // ===== Admin: Pause / Guardian / Delay =====
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external {
        require(msg.sender == guardian || msg.sender == owner, "not guardian/owner");
        paused = false;
        emit Unpaused(msg.sender);
    }

    function setGuardian(address _guardian) external onlyOwner {
        guardian = _guardian;
        emit GuardianSet(_guardian);
    }

    /**
     * @dev minDelay kann nur ERHÖHT werden (nie verringert), um Sicherheit nicht abzuschwächen.
     */
    function setMinDelay(uint256 _newDelay) external onlyOwner {
        require(_newDelay >= minDelay, "cannot decrease");
        require(_newDelay <= 30 days, "too large");
        minDelay = _newDelay;
        emit MinDelaySet(_newDelay);
    }

    // ===== Admin: Targets + Freeze =====
    function setStakingTarget(address target) external onlyOwner {
        require(!stakingTargetFrozen, "staking target frozen");
        stakingTarget = target; // darf 0x0 sein (keine Bindung)
        emit StakingTargetSet(target, false);
    }

    function setAirdropTarget(address target) external onlyOwner {
        require(!airdropTargetFrozen, "airdrop target frozen");
        airdropTarget = target; // darf 0x0 sein (keine Bindung)
        emit AirdropTargetSet(target, false);
    }

    function freezeStakingTarget() external onlyOwner {
        require(!stakingTargetFrozen, "already frozen");
        stakingTargetFrozen = true;
        emit StakingTargetSet(stakingTarget, true);
    }

    function freezeAirdropTarget() external onlyOwner {
        require(!airdropTargetFrozen, "already frozen");
        airdropTargetFrozen = true;
        emit AirdropTargetSet(airdropTarget, true);
    }

    // ===== Views =====
    function budgetOf(Bucket b) public pure returns (uint256) {
        if (b == Bucket.Staking)  return BUDGET_STAKING;
        if (b == Bucket.Airdrop)  return BUDGET_AIRDROP;
        if (b == Bucket.Listings) return BUDGET_LISTINGS;
        return BUDGET_FUTURE;
    }

    function remaining(Bucket b) public view returns (uint256) {
        uint256 cap = budgetOf(b);
        uint256 s = spent[b];
        return s >= cap ? 0 : (cap - s);
    }

    function vaultBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // ===== Queue / Execute =====

    /**
     * @notice Queued eine Auszahlung. Kann NICHT ausgeführt werden, bevor eta erreicht ist.
     *         Queue erfordert "nicht pausiert", damit im Notfall zuerst entsperrt/entschieden werden muss.
     */
    function queueWithdrawal(
        Bucket bucket,
        address to,
        uint256 amount,
        string calldata reason
    ) external onlyOwner returns (uint256 id) {
        require(!paused, "paused");
        require(to != address(0), "to=0");
        require(amount > 0, "amount=0");

        // Zielbindungen (falls gesetzt) bereits beim Queueing erzwingen
        if (bucket == Bucket.Staking && stakingTarget != address(0)) {
            require(to == stakingTarget, "to != stakingTarget");
        }
        if (bucket == Bucket.Airdrop && airdropTarget != address(0)) {
            require(to == airdropTarget, "to != airdropTarget");
        }

        // Vorab prüfen, ob der Betrag innerhalb des verbleibenden Budgets liegt
        require(amount <= remaining(bucket), "exceeds bucket remaining");

        id = nextWithdrawalId++;
        uint64 eta = uint64(block.timestamp + minDelay);

        queue[id] = Withdrawal({
            id: id,
            bucket: bucket,
            to: to,
            amount: amount,
            reason: reason,
            eta: eta,
            executed: false,
            canceled: false
        });

        emit Queued(id, bucket, to, amount, reason, eta, msg.sender);
    }

    /**
     * @notice Führt eine gequeue-te Auszahlung aus, sobald eta erreicht ist.
     *         Kann auch während "paused" ausgeführt werden (Deadlock-Schutz).
     */
    function executeQueued(uint256 id) external nonReentrant {
        Withdrawal storage w = queue[id];
        require(w.id == id, "no such id");
        require(!w.executed, "already executed");
        require(!w.canceled, "canceled");
        require(block.timestamp >= w.eta, "too early");

        // Recheck Budget (kann sich durch andere Executions geändert haben)
        require(w.amount <= remaining(w.bucket), "exceeds bucket at execute");

        // Zielbindungen erneut erzwingen
        if (w.bucket == Bucket.Staking && stakingTarget != address(0)) {
            require(w.to == stakingTarget, "to != stakingTarget");
        }
        if (w.bucket == Bucket.Airdrop && airdropTarget != address(0)) {
            require(w.to == airdropTarget, "to != airdropTarget");
        }

        // State update, dann External Call
        spent[w.bucket] += w.amount;
        w.executed = true;

        (bool ok, ) = w.to.call{value: w.amount}("");
        require(ok, "native transfer failed");

        emit Executed(id, msg.sender);
    }

    /**
     * @notice Storniert eine gequeue-te Auszahlung vor Ausführung.
     */
    function cancelQueued(uint256 id) external onlyOwner {
        Withdrawal storage w = queue[id];
        require(w.id == id, "no such id");
        require(!w.executed, "already executed");
        require(!w.canceled, "already canceled");
        w.canceled = true;
        emit Canceled(id, msg.sender);
    }

    // ===== Native Receive =====
    receive() external payable {
        require(msg.value > 0, "no value");
        emit FundsReceived(msg.sender, msg.value);
    }

    // ===== Safety: Fremde ERC20 retten (kein Zugriff auf natives PENTA) =====
    function rescueForeignERC20(address token, address to, uint256 amount) external onlyOwner {
        require(token != address(0), "token=0");
        require(to != address(0), "to=0");
        // Schutz: Diese Funktion betrifft ausschließlich fremde ERC20-Assets.
        // Der native PENTA-Bestand ist hiervon unberührt und kann NICHT umgangen werden.
        bool ok = IERC20Minimal(token).transfer(to, amount);
        require(ok, "ERC20 rescue failed");
    }
}

