// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

import "../iRollio.sol";
import "../lib/Structs.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract ScoreService is Ownable  {
    using SafeMath for uint256;
    using SafeMath for uint8;

    bool private matchesSet = false;
    bool private diceSorted = false;

    bool private locked  = false;

    /**
        @dev Gives a result of the score for a Roll
        @param _roll The Roll being scored
     */
    function result(Roll memory _roll) public {
        require(!locked, "LOCKED");

        lock();       
        setMatches(_roll);
        
        _roll.prizeIndex = 0;
        _roll.prizePercent = 0;

        // JACKPOT All Sixes (66666)
        // 7775 to 1
        if(isSixes(_roll)){
            unlock();
            _roll.prizeIndex = 1;
            _roll.prizePercent =  _roll.prizePool[0];
            return;
        }

        // Five of a Kind (11111 - 55555)
        // 1295 to 1
        if(isFiveOfAKind(_roll)){
            _roll.prizeIndex = 2;
            _roll.prizePercent =  _roll.prizePool[1];
            unlock();
            return;
        }

        // Four of a Kind (1111, 6666)
        // 51 to 1
        if(isFourOfAKind(_roll)){
            _roll.prizeIndex = 3;
            _roll.prizePercent =  _roll.prizePool[2];
            unlock();
            return;
        }

        // Full House (22233)
        // 25 to 1
        if(isFullHouse(_roll)){
            _roll.prizeIndex = 4;
            _roll.prizePercent =  _roll.prizePool[3];
            unlock();
            return;
        }

        // Large Straight (12345)
        // 32 to 1 (3%)
        if(isLargeStraight(_roll)){            
            _roll.prizeIndex = 5;
            _roll.prizePercent =  _roll.prizePool[4];
            unlock();
            return;
        } 

        // Small Straight (1234)
        // 8 to 1 (12.3%)
        if(isSmallStraight(_roll)){
            _roll.prizeIndex = 6;
            _roll.prizePercent =  _roll.prizePool[5];
            unlock();
            return;
        }    

        // Three of a Kind  (111 - 666)
        // 5.5 to one
        if(isThreeOfAKind(_roll)){
            _roll.prizeIndex = 7;
            _roll.prizePercent =  _roll.prizePool[6];
            unlock();
            return;
        }                       
        
        // Two Pair (2233)
        // 3.3 to 1
        if(isTwoPair(_roll)){            
            _roll.prizeIndex = 8;
            _roll.prizePercent =  _roll.prizePool[7];
            unlock();
            return;
        }

        unlock();        
    }

    /**
        @dev Check if all the dice are 6
     */
    function isSixes(Roll memory _roll) internal view returns(bool) {
        require(locked, "NOT LOCKED");
        
        return ((_roll.dice[0] == 6) && (_roll.dice[1] == 6) && (_roll.dice[2] == 6) && (_roll.dice[3] == 6) && (_roll.dice[4] == 6));
    }     

    /**
        @dev Check if Five Of A Kind (11111 - 55555)
     */
    function isFiveOfAKind(Roll memory _roll) internal view returns(bool) {
        require(locked, "NOT LOCKED");

        return ((_roll.dice[0] == _roll.dice[1]) && (_roll.dice[0] == _roll.dice[2]) && (_roll.dice[0] == _roll.dice[3]) && (_roll.dice[0] == _roll.dice[4]));
    }  

   /**
        @dev Check if Four Of A Kind (3333)
     */
    function isFourOfAKind(Roll memory _roll) internal view returns(bool){     
        require(locked, "NOT LOCKED");

        return ((_roll.matches[0] > 3) || (_roll.matches[1] > 3) || (_roll.matches[2] > 3) || (_roll.matches[3] > 3) || (_roll.matches[4] > 3));        
    }

   /**
        @dev Check if Full House ie (33322)
     */
    function isFullHouse(Roll memory _roll) internal view returns(bool){
        require(locked, "NOT LOCKED");

        return (((_roll.matches[0] > 3 || _roll.matches[0] > 2)) 
        || ((_roll.matches[1] > 3 || _roll.matches[1] > 2)) 
        || ((_roll.matches[2] > 3 || _roll.matches[2] > 2)) 
        || ((_roll.matches[3] > 3 || _roll.matches[3] > 2)) 
        || ((_roll.matches[4] > 3 || _roll.matches[4] > 2)));
    }   

    /**
        @dev Check if Large Straight sequential numbers (no matches 12345)
     */
    function isLargeStraight(Roll memory _roll) internal view returns (bool){
        require(locked, "NOT LOCKED");

        return (_roll.matches[0] == 0) && (_roll.matches[1] == 0)  && (_roll.matches[2] == 0) && (_roll.matches[3] == 0) && (_roll.matches[4] == 0);
    }

    /*
        @dev Check if Small Straight 4 sequential numbers (1234, 2345, 3456)
    */
    function isSmallStraight(Roll memory _roll) internal returns(bool){
        require(locked, "NOT LOCKED");
        
        sortDice(_roll);

         if((_roll.dice[0] == 1) && (_roll.dice[1] == 2) && (_roll.dice[2] == 3) && (_roll.dice[3] == 4) && (_roll.dice[4] != 5))
         {
             //1234
             return true;
         }
        else if((_roll.dice[0] == 2) && (_roll.dice[1] == 3) && (_roll.dice[2] == 4) && (_roll.dice[3] == 5) && (_roll.dice[4] != 5))
        {
            //2345
            return true;
        }
        else if((_roll.dice[4] == 6) && (_roll.dice[3] == 5) && (_roll.dice[2] == 4) && (_roll.dice[1] == 3) && (_roll.dice[0] != 2))
        {
            //3456
            return true;
        }
      
        return false;
    }

    /**
        @dev Check if Three Of A Kind ie 333xx;
     */
    function isThreeOfAKind(Roll memory _roll) internal view returns(bool){
        require(locked, "NOT LOCKED");
        return (_roll.matches[0] == 3 || _roll.matches[1] == 3 || _roll.matches[2] == 3 || _roll.matches[3] == 3 || _roll.matches[4] == 3);
    }  

    /**
        @dev Check if Two Pairs (2233);
     */
    function isTwoPair(Roll memory _roll) internal view returns(bool){
        require(locked, "NOT LOCKED");
        uint8 p = 0;
        for(uint8 i = 0; i < _roll.matches.length; i++){
            if(_roll.matches[i] == 2){
                p++;
            }
        }
        return (p == 2);
    }     

    /**
        @dev Loop through dice and find combinations for easier scoring
     */
    function setMatches(Roll memory _roll) internal  {
        require(locked, "NOT LOCKED");
        if(!matchesSet){
            for (uint i = 0; i < _roll.dice.length; i++) {
                _roll.matches[_roll.dice[i] - 1] = uint8((_roll.matches[_roll.dice[i] - 1] + 1));
            }
            matchesSet = true;
        }
    }

    /**
        @dev Bubble Sort Helper to put dice in numeric order
     */
    function sortDice(Roll memory _roll) internal {
        require(locked, "NOT LOCKED");
        
        if(diceSorted){
            diceSorted = true;
            bool done = false;
            while(!done){
                done = true;
                for (uint i = 1; i < _roll.dice.length; i++) {
                    if(_roll.dice[i-1] > _roll.dice[i]){
                        done = false;
                        uint8 tmp = _roll.dice[i - 1];
                        _roll.dice[i - 1] = _roll.dice[i];
                        _roll.dice[i] = tmp;
                    }
                }            
            }
        }
    }

    /**
        @dev Admin Lock the contract 
     */
    function lock() private {
        locked = true;
    }

    /**
        @dev Admin Unlock contract
     */
    function unlock() private {
        locked = false;
    }
}