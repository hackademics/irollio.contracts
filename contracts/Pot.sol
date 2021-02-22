// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

import "./iRollio.sol";
import "./lib/Structs.sol";
import "@openzeppelin/contracts/payment/PullPayment.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Pot is Initializable, Ownable, PullPayment {
    using SafeMath for uint256;
    using Address  for address;

    mapping(address => uint) public entries;  
    
    uint     public wins = 0;
    uint     public jackpots = 0;
    bool     public locked = false;
    uint     public interval = 8 hours;
    uint256  public entryWei;
    uint8[8] public prizePool;
    uint256  public precisionMinimum = 0.04 ether;
    uint256  private valuation = 4000 ether;
    
    event Initialized(address sender, uint256 entryWei, uint interval, uint8[8] prizePool);
    event Seeded(address sender, uint256 amount);
    event Entered(address sender, uint256 entryWei);
    event NotAllowed(address sender, uint blocktime, uint lastEntry);
    event Transfered(address sender, Roll roll);
    event Claimed(address sender);
    event OwnerChanged(address sender, address newOwner);
    
    /**
        @dev Constructor to make new Pot Contract
        @dev Verbose declaration of prizes have to be cascading
        @param _entryWei Entry Fee to deposit to gain roll
        @param _interval      Amount of time in Hours allowed between player rolls;
        @param _jackpot       Percent of pot if won JackPot (all sixes)
        @param _fiveOAK       Percent of pot for Five of Kind roll
        @param _fourOFAK      Percent of pot for Four of a Kind roll
        @param _fullHouse     Percent of pot for Full House roll
        @param _largeStraight Percent of pot for Large Straight roll
        @param _threeOAK      Percent of pot for Three of a Kind roll
        @param _smallStraight Percent of pot for Small Straight roll
        @param _twoPair       Percent of pot for Two Pair roll
     */
    constructor (uint256 _entryWei, uint _interval, uint8 _jackpot, uint8 _fiveOAK, uint8 _fourOFAK,  uint8 _fullHouse, uint8 _largeStraight, uint8 _threeOAK, uint8 _smallStraight, uint8 _twoPair) public payable {
        require(_entryWei > 0, "Invalid Entry Fee");  
        require(_interval > 0, "Invalid Interval"); 
        require(_jackpot > 0 && _jackpot <= 90, "Invalid Jackpot Prize");   
        require(_fiveOAK < _jackpot, "Invalid Five of a Kind Prize");  
        require(_fourOFAK < _fiveOAK, "Invalid Four of a Kind Prize");   
        require(_fullHouse < _fourOFAK, "Invalid Full House Prize");   
        require(_largeStraight < _fullHouse, "Invalid Large Straight Prize"); 
        require(_threeOAK < _largeStraight, "Invalid Three of a Kind Prize"); 
        require(_smallStraight < _threeOAK, "Invalid Small Straight Prize"); 
        require(_twoPair < _smallStraight, "Invalid Two Pair Prize"); 

        //SEED
        if(msg.value > 0){
            address(this).balance.add(msg.value);
        }        
        
        interval  = _interval;
        entryWei  = _entryWei;
        prizePool = [_jackpot,_fiveOAK,_fourOFAK,_fullHouse,_largeStraight,_threeOAK,_smallStraight,_twoPair];

        Initialized(msg.sender, entryWei, interval, prizePool);
    }

    /**
        @dev Player enters the game with proper entryWei for contract
     */
    function enter(Roll memory _roll) external payable returns(bool) {
        require(!locked, "Locked");
        require(msg.value == entryWei, "Invalid EntryWei");
        
        lock();        
            if(allowed()){
                _roll.initBalance = address(this).balance;
                _roll.rollBalance = address(this).balance.add(msg.value);                
                entries[msg.sender] = block.timestamp;
                Entered(msg.sender, msg.value);
                return true;
            }
        unlock();

        return false;       
    }

    /**
        @dev check to see if it's been interval hours since last roll
     */
    function allowed() public view returns(bool) {
        uint o = entries[msg.sender];
        if(o > 0 && (block.timestamp - o) < interval) {  
           return false;
        }
        return true;
    }

    /**
        @dev Calculate and Transfer Winnings
     */
    function payout(Roll memory _roll) external {
        require(!locked, "Locked");
        require(_roll.prizePercent > 0, "No Winner");
        require(_roll.prizeIndex > 0, "No Winner");
        require(_roll.prizePercent < 90, "Invalid Prize Percent");        
        
        lock();
            _roll.won = address(this).balance.mul(_roll.prizePercent).div(100);
            _asyncTransfer(msg.sender, _roll.won);
            _roll.postBalance = address(this).balance;
            emit Transfered(msg.sender, _roll);
        unlock();        
    }

    /**
        @dev Withdraw all payments sent to address 
        @param _player Address of the player claiming funds
     */
    function claim(address payable _player) public {
        require(!locked, "Locked");

        lock();
            withdrawPayments(_player);
            Claimed(msg.sender);
        unlock();
    }

    /**
        @dev Get the claims due to the winners
        @param _player Address to look up winnings for
     */
    function claims(address _player) public view returns(uint256){
        return payments(_player);
    }
    
    /**
        @dev Allow the contract to be seeded after initialization
     */
    function seed() public payable onlyOwner {
        require(address(this).balance == 0, "Already Seeded");
        require(!locked, "Locked");
        
        lock();
            address(this).balance.add(msg.value);
        unlock();
    }

    /**
        @dev Get the current balance of the pot;
     */
    function potBalance() public view returns(uint256) {
        return address(this).balance;
    }


    /**
        @dev Change ownership of contract
        @param _newOwner Address of the new Owner of the contract
     */
    function transferOwner(address _newOwner) public onlyOwner {
        require(_newOwner != address(0x0));
        require(!locked, "Locked");

        emit OwnerChanged(msg.sender,_newOwner);
    }   

    /**
        @dev Admin Lock the contract 
     */
    function lock() public onlyOwner {
        locked = true;
    }

    /**
        @dev Admin Unlock contract
     */
    function unlock() public onlyOwner {
        locked = false;
    }
}