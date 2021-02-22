// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

struct Roll {        
    uint8[5] dice;
    uint8[5] diceSorted;
    uint8[6] matches;
    uint8[8] prizePool;
    address  player;
    address  pot;
    uint256  seed;   
    uint256  vrfNum;
    bytes32  vrfId;     
    uint256  won;
    uint256  prizeIndex;
    uint256  prizePercent;        
    uint256  initBalance;
    uint256  rollBalance;
    uint256  postBalance;
    uint     ts;        
}