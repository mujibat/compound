// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import { ReceiptToken } from "contracts/receiptToken.sol";
interface IStaking {
   function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool success);
    function mint(address account, uint256 value) external;

}
interface IWETH {
    function deposit() external payable;
    function balanceOf(address user)external view returns(uint256);
}
contract ReceiptToken is ERC20{
     address receipt;

    constructor() ERC20("LMAOTOK", "LMOT"){
        _mint(msg.sender, 1_000_000e18);
        receipt = msg.sender;    
    }
     function mint(address account, uint256 value) external {
        _mint(account, value);
    }
}
contract RewardToken is ERC20{
     address reward;

    constructor() ERC20("LMAOTOK", "LMOT"){
        _mint(msg.sender, 1_000_000e18);
        reward = msg.sender;  
    }
}



contract DolStakingContract {

    IERC20 public stakingToken;
    IStaking public rewardtoken;
    IStaking public receipttoken;
    ReceiptToken public rewardToken;
    uint256 public annualizedRate = 14; 
    
   
    IWETH weth;
    

    struct UserInfo {
        uint256 stakedAmount;
        uint256 lastClaimTime;
        uint256 stakingBalance;
        uint256 startTime;
        uint256 stakingDuration;
        bool autoCompound;
        address[] autocompounders;
        uint256 totalStaked;
    }
    uint totalAutoCompoundingFee;

    mapping(address => UserInfo) public userInfo;
    mapping(address => uint) public stakersBalance;

    constructor(address _receipttoken, address _rewardtoken, address _wethtoken) {
        receipttoken = IStaking(_receipttoken);
        rewardtoken = IStaking(_rewardtoken);
        weth = IWETH(_wethtoken);
    }
   
    

     function stakeETH(uint _durationTime) external payable{
        UserInfo storage user = userInfo[msg.sender];
        user.stakingDuration = block.timestamp + _durationTime;
        require(block.timestamp < user.stakingDuration, "Not within duration");
        require(msg.value > 0, "Amount must be greater than 0");
        stakersBalance[msg.sender] += msg.value;
        IWETH(weth).deposit{value:msg.value}();
        uint256 receipt = calculateReceipt(msg.sender);
        require(receipt > 0, "receipt token failed");
        receipttoken.mint(msg.sender, receipt);
        totalAutoCompoundingFee += msg.value;
    }
   
     function calculateReceipt(address userAddress) public view returns (uint256) {
        UserInfo storage user = userInfo[userAddress];
        uint256 stakedAmount = (14 * user.stakedAmount) / 100;

        // Calculate rewards based on annualized rate
        uint256 receipt = stakedAmount * user.stakedAmount * user.stakingDuration / 365 days / user.totalStaked;

        return receipt;
    }

     function toggleAutoCompound() external {
         UserInfo storage user = userInfo[msg.sender];
        user.autoCompound = !user.autoCompound;
        user.autocompounders.push(msg.sender);
    }

 

     /*
    users are only allowed to bring in ETH which is automatically converted to WETH
     before being deposited into the contract and 
     a receipt token called (yourTokenName-WETH) is minted to them 
     based on the proportion they submitted of course, 
     users can decide to opt in for auto compounding
     (at just a 1% fee of their WETH monthly) which can be triggered by anyone externally,
     the person who triggers this gets a certain reward as a replacement for the gas fee spent,
      the reward comes from the total auto-compounding fee of people in the pool
    // */
    function calculateAutocompound(address) internal {
        UserInfo storage user = userInfo[msg.sender];
        uint onepercent = (user.totalStaked * 1) / 100;
        uint remain = user.totalStaked - onepercent;
        uint compoundCalc = ((annualizedRate / 100) / 12) + 1;
        uint compound = (user.stakedAmount * compoundCalc) ** 12; 
       uint compoundinterest = onepercent + compound;
       payable(msg.sender).transfer(compoundinterest);
    }
    function triggerAutoCompound() external {
        UserInfo storage user = userInfo[msg.sender];
        require(user.autoCompound == true, "Toggle Autocompound");
            address[] memory autocompounders = user.autocompounders;
        for(uint i= 0; i < autocompounders.length; i++) {
            address compounder = autocompounders[i];

            uint amountToRefund =  calculateAutocompound(msg.sender);
            // crow.fundingBalance -= amountToRefund;
            stakersBalance[compounder] -= amountToRefund;
            payable(compounder).transfer(amountToRefund);
        }
    }
   
   
}