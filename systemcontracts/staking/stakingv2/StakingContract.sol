// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }

    function ceil(uint256 a, uint256 m) internal pure returns (uint256) {
        uint256 c = add(a,m);
        uint256 d = sub(c,1);
        return mul(div(d,m),m);
    }
}

interface IStakingContract {
    //Deposit
    function newDeposit(address validatorAddress) external payable;

    //Pause
    function pauseValidation() external;

    //Resume
    function resumeValidation() external;

    //Withdraw
    function initiateWithdrawal() external returns (uint256);
    function completeWithdrawal() external returns (uint256);

    //Rewards and Slashing
    function addDepositorSlashing(address depositorAddress, uint256 slashAmount) external returns (uint256);
    function addDepositorReward(address depositorAddress, uint256 rewardAmount) external returns (uint256);

    //get data
    function getDepositorCount() external view returns (uint256);
    function getTotalDepositedBalance() external view returns (uint256);
    function listValidators() external view returns (address[] memory);
    function getDepositorOfValidator(address validatorAddress) external view returns (address);
    function getValidatorOfDepositor(address depositorAddress) external view returns (address);
    function getBalanceOfDepositor(address depositorAddress) external view returns (uint256);
    function getNetBalanceOfDepositor(address depositorAddress) external view returns (uint256);
    function getDepositorRewards(address depositorAddress) external view returns (uint256);
    function getDepositorSlashings(address depositorAddress) external view returns (uint256);
    function getWithdrawalBlock(address depositorAddress) external view returns (uint256);
    function isValidationPaused(address validatorAddress) external view returns (bool);

    function doesValidatorExist(address validatorAddress) external view returns (bool);
    function didValidatorEverExist(address validatorAddress) external view returns (bool);
    function doesDepositorExist(address depositorAddress) external view returns (bool);
    function didDepositorEverExist(address depositorAddress) external view returns (bool);

    //Staking V2 functions

    //Rotate
    function changeValidator(address newValidatorAddress) external;
    function changeDepositor(address newDepositorAddress) external;

    //Deposit
    function increaseDeposit() external payable;

    //Withdrawal
    function initiateWithdrawalRewards() external returns (uint256);
    function completeWithdrawalRewards() external returns (uint256);
    function getRewardsWithdrawalDetails(address depositorAddress) external view returns (uint256,uint256);

    event OnNewDeposit(
        address indexed depositorAddress,
        address indexed validatorAddress,
        uint256 amount,
        uint256 blockNumber,
        uint256 blockTime
    );

    event OnPauseValidation(
        address depositorAddress,
        address validatorAddress
    );

    event OnResumeValidation(
        address depositorAddress,
        address validatorAddress
    );

    event OnInitiateWithdrawal(
        address depositorAddress
    );

    event OnCompleteWithdrawal(
        address depositorAddress,
        uint256 netBalance
    );

    event OnSlashing(address indexed depositorAddress,
        uint256 slashedAmount);

    event OnReward(address indexed depositorAddress,
        uint256 rewardAmount);

    //Staking V2 events
    event OnChangeValidator(address indexed depositorAddress, address indexed oldValidatorAddress, address indexed newValidatorAddress);
    event OnChangeDepositor(address indexed oldDepositorAddress, address indexed newDepositorAddress);

    event OnIncreaseDeposit(address indexed depositorAddress, uint256 oldBalance, uint256 newBalance);

    event OnInitiateWithdrawalRewards(address indexed depositorAddress, uint256 withdrawalBlock, uint256 withdrawalQuantity);
    event OnCompleteWithdrawalRewards(address indexed depositorAddress, uint256 withdrawalQuantity);
}

contract StakingContract is IStakingContract {
    using SafeMath for uint256;

    uint256 constant MINIMUM_DEPOSIT = 5000000000000000000000000; //5000000
    uint256 constant WITHDRAWAL_BLOCK_DELAY = 32000;

    address[] private _validatorList;

    //depositor balance
    mapping (address => uint256) private _depositorBalances;

    //total amount
    uint256 private _totalDepositedBalance = 0;

    //depositor count
    uint256 private _depositorCount = 0;

    //depositor and validator exists
    mapping (address => bool) private _validatorExists;
    mapping (address => bool) private _depositorExists;

    mapping (address => bool) private _validatorEverExisted;
    mapping (address => bool) private _depositorEverExisted;

    //depositor and validator reverse mapping
    mapping (address => address) private _validatorToDepositorMapping;
    mapping (address => address) private _depositorToValidatorMapping;

    //Slashings
    mapping (address => uint256) private _depositorSlashings;

    //Rewards
    mapping (address => uint256) private _depositorRewards;

    //Withdrawal Request, depositor to withdrawalBlock
    mapping (address => uint256) private _depositorWithdrawalRequests;

    //Whether validation is paused
    mapping (address => bool) private _validationPaused;

    //StakingV2 variables

    //Withdrawal Request, depositor to withdrawalBlock
    mapping (address => uint256) private _depositorRewardsWithdrawalRequestsMapping;
    mapping (address => uint256) private _depositorRewardsWithdrawalAmountMapping;

    function newDeposit(address validatorAddress) override external payable {
        address depositorAddress = msg.sender;
        uint256 depositAmount = msg.value;
        require(depositAmount >= MINIMUM_DEPOSIT, "Deposit amount below minimum deposit amount");
        require(depositorAddress != validatorAddress, "Depositor address cannot be same as Validator address");
        require(validatorAddress != address(0), "Invalid validator");

        require(_validatorExists[validatorAddress] == false, "Validator already exists");
        require(_validatorEverExisted[validatorAddress] == false, "Validator existed once");

        require(_validatorExists[depositorAddress] == false, "Validator already exists as new depositor");
        require(_validatorEverExisted[depositorAddress] == false, "Validator existed once as new depositor");

        uint256 validatorBalance = validatorAddress.balance;
        require(validatorBalance == 0, "validator balance should be zero"); //Since we don't check validator signature, atleast verify if zero balance

        require(_depositorExists[depositorAddress] == false, "Depositor already exists");
        require(_depositorEverExisted[depositorAddress] == false, "Depositor existed once");

        require(_depositorExists[validatorAddress] == false, "Depositor already exists as new validator once");
        require(_depositorEverExisted[validatorAddress] == false, "Depositor existed once as new validator");

        _validatorList.push(validatorAddress);
        _totalDepositedBalance = _totalDepositedBalance.add(depositAmount);
        _depositorCount = _depositorCount.add(1);
        _depositorBalances[depositorAddress] = depositAmount;

        _validatorExists[validatorAddress] = true;
        _depositorExists[depositorAddress] = true;
        _validatorEverExisted[validatorAddress] = true;
        _depositorEverExisted[depositorAddress] = true;

        _validatorToDepositorMapping[validatorAddress] = depositorAddress;
        _depositorToValidatorMapping[depositorAddress] = validatorAddress;

        emit OnNewDeposit(
            depositorAddress,
            validatorAddress,
            depositAmount,
            block.number,
            block.timestamp
        );
    }

    function pauseValidation() override external {
        address depositorAddress = msg.sender;
        require(_depositorExists[depositorAddress] == true, "Depositor does not exist");

        address validatorAddress = _validatorToDepositorMapping[depositorAddress];
        require(_validationPaused[validatorAddress] == false, "Validation is already paused");
        _validationPaused[validatorAddress] = true;

        emit OnPauseValidation(depositorAddress, validatorAddress);
    }

    function resumeValidation() override external {
        address depositorAddress = msg.sender;
        require(_depositorExists[depositorAddress] == true, "Depositor does not exist");

        address validatorAddress = _validatorToDepositorMapping[depositorAddress];
        require(_validationPaused[validatorAddress] == true, "Validation is not paused");
        _validationPaused[validatorAddress] = false;

        emit OnResumeValidation(depositorAddress, validatorAddress);
    }

    function initiateWithdrawal() override external returns (uint256) {
        address depositorAddress = msg.sender;
        require(_depositorExists[depositorAddress] == true, "Depositor does not exist");
        require(_depositorWithdrawalRequests[depositorAddress] == 0, "Depositor withdrawal request exists");
        require(_depositorBalances[depositorAddress] > 0, "Depositor balance is zero");
        require(_depositorRewardsWithdrawalRequestsMapping[depositorAddress] == 0, "Depositor rewards withdrawal request exists");

        uint256 netBalance = this.getNetBalanceOfDepositor(depositorAddress);
        require(netBalance > 0, "Depositor net balance is zero");

        _depositorWithdrawalRequests[depositorAddress] = block.number + WITHDRAWAL_BLOCK_DELAY;
        _depositorExists[depositorAddress] = false;

        emit OnInitiateWithdrawal(depositorAddress);

        return netBalance;
    }

    function completeWithdrawal() override external returns (uint256) {
        address depositorAddress = msg.sender;
        require(_depositorWithdrawalRequests[depositorAddress] > 0, "Depositor withdrawal request does not exist");
        require(block.number >= _depositorWithdrawalRequests[depositorAddress] || (_depositorWithdrawalRequests[depositorAddress] - block.number) > WITHDRAWAL_BLOCK_DELAY, "Depositor withdrawal request cutoff block not reached");

        uint256 balance = _depositorBalances[depositorAddress].add(_depositorRewards[depositorAddress]);
        require(balance > _depositorSlashings[depositorAddress], "balance is negative");
        uint256 netBalance = balance.sub(_depositorSlashings[depositorAddress]);

        delete _depositorBalances[depositorAddress];
        delete _depositorRewards[depositorAddress];
        delete _depositorSlashings[depositorAddress];
        delete _depositorExists[depositorAddress];
        delete _depositorWithdrawalRequests[depositorAddress];

        (bool success, ) = depositorAddress.call{value:netBalance}("");
        // success should be true
        require(success,"Withdraw failed");

        emit OnCompleteWithdrawal(depositorAddress, netBalance);

        return netBalance;
    }

    function addDepositorSlashing(address depositorAddress, uint256 slashAmount) override external returns (uint256) {
        require(msg.sender == address(0), "Only VM calls are allowed");
        _depositorSlashings[depositorAddress] = _depositorSlashings[depositorAddress].add(slashAmount);

        address zeroAddress = address(0);
        (bool success, ) = zeroAddress.call{value:slashAmount}("");
        // success should be true
        require(success,"transfer to zeroAddress failed");

        emit OnSlashing(depositorAddress, slashAmount);
        return _depositorSlashings[depositorAddress];
    }

    function addDepositorReward(address depositorAddress, uint256 rewardAmount) override external returns (uint256) {
        require(msg.sender == address(0), "Only VM calls are allowed");
        _depositorRewards[depositorAddress] = _depositorRewards[depositorAddress].add(rewardAmount);
        emit OnReward(depositorAddress, rewardAmount);
        return _depositorRewards[depositorAddress];
    }

    function getDepositorCount() override external view returns (uint256) {
        return _depositorCount;
    }

    function getTotalDepositedBalance() override external view returns (uint256) {
        return _totalDepositedBalance;
    }

    function listValidators() override external view returns (address[] memory) {
        return _validatorList;
    }

    function getDepositorOfValidator(address validatorAddress) override external view returns (address) {
        address depositorAddress = _validatorToDepositorMapping[validatorAddress];
        return depositorAddress;
    }

    function getValidatorOfDepositor(address depositorAddress) override external view returns (address) {
        address validatorAddress = _depositorToValidatorMapping[depositorAddress];
        return validatorAddress;
    }

    function getBalanceOfDepositor(address depositorAddress) override external view returns (uint256) {
        return _depositorBalances[depositorAddress];
    }

    function getNetBalanceOfDepositor(address depositorAddress) override external view returns (uint256) {
        if (_depositorExists[depositorAddress] == false) {
            return 0;
        }

        if (_depositorWithdrawalRequests[depositorAddress] > 0) {
            return 0;
        }

        uint256 balance = _depositorBalances[depositorAddress].add(_depositorRewards[depositorAddress]);
        if (balance <= _depositorSlashings[depositorAddress]) {
            return 0;
        }

        return balance.sub(_depositorSlashings[depositorAddress]);
    }

    function getDepositorRewards(address depositorAddress) override external view returns (uint256) {
        return _depositorRewards[depositorAddress];
    }

    function getDepositorSlashings(address depositorAddress) override external view returns (uint256) {
        return _depositorSlashings[depositorAddress];
    }

    function getWithdrawalBlock(address depositorAddress) override external view returns (uint256) {
        return _depositorWithdrawalRequests[depositorAddress];
    }

    function isValidationPaused(address validatorAddress) override external view returns (bool) {
        return _validationPaused[validatorAddress];
    }

    function doesValidatorExist(address validatorAddress) override external view returns (bool) {
        return _validatorExists[validatorAddress];
    }

    function didValidatorEverExist(address validatorAddress) override external view returns (bool) {
        return _validatorEverExisted[validatorAddress];
    }

    function doesDepositorExist(address depositorAddress) override external view returns (bool) {
        return _depositorExists[depositorAddress];
    }

    function didDepositorEverExist(address depositorAddress) override external view returns (bool) {
        return _depositorEverExisted[depositorAddress];
    }

    function changeValidator(address newValidatorAddress) override external {
        require(_validatorExists[newValidatorAddress] == false, "Validator already exists");
        require(_depositorExists[newValidatorAddress] == false, "Validator is a depositor");
        require(_validatorEverExisted[newValidatorAddress] == false, "Validator already existed");
        require(_depositorEverExisted[newValidatorAddress] == false, "Depositor already existed");
        require(newValidatorAddress.balance == 0, "validator balance should be zero"); //Since we don't check validator credentials, atleast verify if zero balance
        require(newValidatorAddress != address(0), "Invalid validator");

        address depositorAddress = msg.sender;
        require(depositorAddress != newValidatorAddress, "Depositor address cannot be same as Validator address");

        require(_depositorExists[depositorAddress] == true, "Depositor does not exist");
        require(_depositorWithdrawalRequests[depositorAddress] == 0, "Withdrawal is pending");

        address oldValidatorAddress = _depositorToValidatorMapping[depositorAddress];

        _validatorExists[newValidatorAddress] = true;
        _validatorEverExisted[newValidatorAddress] = true;

        _validatorToDepositorMapping[newValidatorAddress] = depositorAddress;
        _depositorToValidatorMapping[depositorAddress] = newValidatorAddress;
        _validatorList.push(newValidatorAddress);

        _validatorExists[oldValidatorAddress] = false;
        delete _validatorToDepositorMapping[oldValidatorAddress];

        bool validationPaused = _validationPaused[oldValidatorAddress];
        if(validationPaused == true) {
            delete(_validationPaused[oldValidatorAddress]);
            _validationPaused[newValidatorAddress] = validationPaused;
        }

        emit OnChangeValidator(depositorAddress, oldValidatorAddress, newValidatorAddress);
    }

    function changeDepositor(address newDepositorAddress) override external {
        address oldDepositorAddress = msg.sender;

        require(_depositorExists[oldDepositorAddress] == true, "Depositor does not exist");
        require(_depositorExists[newDepositorAddress] == false, "newDepositorAddress already exists");
        require(_depositorEverExisted[newDepositorAddress] == false, "newDepositorAddress existed once");
        require(_depositorBalances[oldDepositorAddress] > 0, "Depositor balance is zero");
        require(_validatorExists[newDepositorAddress] == false, "Validator already exists as newDepositorAddress");
        require(_validatorEverExisted[newDepositorAddress] == false, "Validator already existed as newDepositorAddress");

        //Update balance
        uint256 depositorBalance = _depositorBalances[oldDepositorAddress];
        _depositorBalances[newDepositorAddress] = depositorBalance;

        //Update depositor exists maps
        _depositorExists[newDepositorAddress] = true;
        _depositorExists[oldDepositorAddress] = false;

        //Update depositor ever exist mapping
        _depositorEverExisted[newDepositorAddress] = true;

        //Update depositor to validate map
        address validatorAddress = _depositorToValidatorMapping[oldDepositorAddress];
        delete _depositorToValidatorMapping[oldDepositorAddress];
        _depositorToValidatorMapping[newDepositorAddress] = validatorAddress;

        //Update validator to depositor map
        _validatorToDepositorMapping[validatorAddress] = newDepositorAddress;

        //Update depositor slashings
        uint256 depositorSlashings = _depositorSlashings[oldDepositorAddress];
        delete _depositorSlashings[oldDepositorAddress];
        _depositorSlashings[newDepositorAddress] = depositorSlashings;

        //Update depositor rewards
        uint256 depositorRewards = _depositorRewards[oldDepositorAddress];
        delete _depositorRewards[oldDepositorAddress];
        _depositorRewards[newDepositorAddress] = depositorRewards;

        //Update withdrawal request
        if(_depositorWithdrawalRequests[oldDepositorAddress] > 0) {
            uint256 depositorWithdrawalBlock = _depositorWithdrawalRequests[oldDepositorAddress];
            delete(_depositorWithdrawalRequests[oldDepositorAddress]);
            _depositorWithdrawalRequests[newDepositorAddress] = depositorWithdrawalBlock;
        }

        if(_depositorRewardsWithdrawalRequestsMapping[oldDepositorAddress] > 0) {
            uint256 depositorRewardsWithdrawalBlock = _depositorRewardsWithdrawalRequestsMapping[oldDepositorAddress];
            delete(_depositorRewardsWithdrawalRequestsMapping[oldDepositorAddress]);
            _depositorRewardsWithdrawalRequestsMapping[newDepositorAddress] = depositorRewardsWithdrawalBlock;

            uint256 depositorRewardsWithdrawalAmount = _depositorRewardsWithdrawalAmountMapping[oldDepositorAddress];
            delete(_depositorRewardsWithdrawalAmountMapping[oldDepositorAddress]);
            _depositorRewardsWithdrawalAmountMapping[newDepositorAddress] = depositorRewardsWithdrawalAmount;
        }

        emit OnChangeDepositor(oldDepositorAddress, newDepositorAddress);
    }

    function increaseDeposit() override external payable {
        address depositorAddress = msg.sender;
        require(_depositorExists[depositorAddress] == true, "Depositor does not exist");
        require(_depositorWithdrawalRequests[depositorAddress] == 0, "Depositor withdrawal request exists");

        uint256 depositAmount = msg.value;
        require(depositAmount > 0, "Deposit amount is zero");

        uint256 oldBalance = _depositorBalances[depositorAddress];
        uint256 newBalance = oldBalance.add(depositAmount);

        _depositorBalances[depositorAddress] = newBalance;

        emit OnIncreaseDeposit(depositorAddress, oldBalance, newBalance);
    }

    function initiateWithdrawalRewards() override external returns (uint256) {
        address depositorAddress = msg.sender;
        require(_depositorExists[depositorAddress] == true, "Depositor does not exist");
        require(_depositorWithdrawalRequests[depositorAddress] == 0, "Depositor withdrawal request exists");
        require(_depositorBalances[depositorAddress] > 0, "Depositor balance is zero");
        require(_depositorRewardsWithdrawalRequestsMapping[depositorAddress] == 0, "Depositor rewards withdrawal request exists");

        uint256 rewards = _depositorRewards[depositorAddress];
        require(rewards > 0, "Depositor rewards is zero");
        delete(_depositorRewards[depositorAddress]);

        _depositorRewardsWithdrawalRequestsMapping[depositorAddress] = block.number + WITHDRAWAL_BLOCK_DELAY;
        _depositorRewardsWithdrawalAmountMapping[depositorAddress] = rewards;

        emit OnInitiateWithdrawalRewards(depositorAddress, block.number + WITHDRAWAL_BLOCK_DELAY, rewards);

        return rewards;
    }

    function completeWithdrawalRewards() override external returns (uint256) {
        address depositorAddress = msg.sender;
        require(_depositorExists[depositorAddress] == true, "Depositor does not exist");
        require(_depositorRewardsWithdrawalRequestsMapping[depositorAddress] > 0, "Depositor rewards withdrawal request does not exist");
        require(block.number >= _depositorRewardsWithdrawalRequestsMapping[depositorAddress], "Depositor rewards withdrawal request cutoff block not reached");

        uint256 rewards = _depositorRewardsWithdrawalAmountMapping[depositorAddress];
        delete _depositorRewardsWithdrawalRequestsMapping[depositorAddress];
        delete _depositorRewardsWithdrawalAmountMapping[depositorAddress];

        (bool success, ) = depositorAddress.call{value:rewards}("");
        // success should be true
        require(success,"Withdraw rewards failed");

        emit OnCompleteWithdrawalRewards(depositorAddress, rewards);

        return rewards;
    }

    function getRewardsWithdrawalDetails(address depositorAddress) override external view returns (uint256,uint256) {
        return (_depositorRewardsWithdrawalRequestsMapping[depositorAddress], _depositorRewardsWithdrawalAmountMapping[depositorAddress]);
    }
}