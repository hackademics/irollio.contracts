// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

import "./VRFService.sol";
import "@openzeppelin/contracts/payment/PullPayment.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Pot is Ownable, PullPayment {    
    using SafeMath for *;
	using Address  for address;

    struct Roll { address usr; uint8 d1; uint8 d2; uint8 d3; uint8 d4; uint8 d5; uint8 pr; uint48 ts; bytes32 id; uint256 rand; uint256 w; }   
    
    enum STA {I, O, C} 
    enum LCK {U, L} 

    address   payable public pO;
    string    public  pN;
    uint48    public  pC;
    uint8[11] public  pP; 
    uint256   public  pT;
    uint256   public  pF;
    uint256   public  pSM;
    LCK       public  lck;
    STA       public  sta;   
    Roll[]    public  rolls;
    
    mapping (address => uint)    public bi;
    mapping (address => bytes32) public rids;

    event EVSE(address indexed usr,uint a,uint ct);
    event EVBI(address indexed usr,uint a,uint ct);
    event EVRS(address indexed usr,Roll roll,uint rolls);
    event EVPO(address indexed usr,uint256 w,uint256 pt,uint256 b);
    event EVCL(address indexed usr);

    modifier locked(LCK _l){require((lck==l),"plk");_;} 
    modifier sOf(STA _s)   {require((sta==_s),"pst");_;} 
    modifier isPO()        {require((msg.sender==pO)||(msg.sender==owner()),"ppo");_;}
    modifier isExpr()      {require(expired(), "pex");_;}

    constructor (address payable _po, uint8[11] memory _pp, uint256 _pf, string memory _pn) public{
        require(_po != address(0), "pcpo");
        require(_pf > 0, "pcpf");
        require(vpp(_pp));
        pO = _po;
        pP = _pp;
        pF = _pf;
        pN = _pn;
        pC = uint48(block.timestamp);        
        pT = 0;  
        sta = STA.I;
        lck = LCK.U;
    }

    function buy(uint256 _s) external locked(LCK.U) sOf(STA.O) isExpr() payable returns(bytes32){
        require(msg.value == pF, "pbipf");        
        lck = LCK.L;
            bi[msg.sender] = bi[msg.sender].add(msg.value);
            pT = pT.add(msg.value);        
            emit EVBI(msg.sender, msg.value, pT);
            rids[msg.sender] = new VRFService().request(_s);
        lck = LCK.U;  
        return rids[msg.sender];
    }

    function vrfR(bytes32 _id, uint256 _n) external {
        require(_n > 0, "pvn");
        require(rids[msg.sender] == _id, "vrfrds");        
        uint256 w = 0;
        (uint8 per, uint8 d1, uint8 d2, uint8 d3, uint8 d4, uint8 d5) = score(_n);
        if(per > 0){ w = pay(per);}
        Roll memory r = Roll(msg.sender, d1, d2, d3, d4, d5, per, uint48(block.timestamp), _id, _n, w);
        require(save(r), "pvrsr");        
    }

    function pay(uint8 _p) public locked(LCK.U) sOf(STA.O) returns(uint256) {
        require(_p < 90, "ppoper");
        lck = LCK.L;        
            uint256 w = address(this).balance.mul(_p).div(100);
            _asyncTransfer(msg.sender, w);        
            pT = pT.sub(w);
            if(pT != address(this).balance){
                sta = STA.C; 
                emit EVCL(msg.sender); 
            }
            emit EVPO(msg.sender, w, pT, address(this).balance);
        lck = LCK.U;
        return w;
    }

    function save(Roll memory _r) internal locked(LCK.U) sOf(STA.O) returns(bool){        
        lck = LCK.L;        
            rolls[rolls.length - 1] = _r;        
            emit EVRS(msg.sender, _r, rolls.length);
        lck = LCK.U;
        return true;
    } 

    function usrLast() public sOf(STA.O) view returns(Roll memory _r) {
        for (uint i = rolls.length; i > 0; i--) {
            if(rolls[i].usr == msg.sender){
                return rolls[i];
            }
        }
    } 

    function expired() public sOf(STA.O) view returns(bool){
        return (usrLast().ts +8 hours >= uint48(block.timestamp));
    }   

    function seed() public locked(LCK.U) isPO() sOf(STA.O) payable returns(bool){
        require(msg.value >= pSM, "psppsm");
        lck = LCK.L;
            pT = pT.add(msg.value);
            sta = STA.O;
            emit EVSE(msg.sender, msg.value, pT);
        lck = LCK.U;
        return true;
    }

    function close() public locked(LCK.U) sOf(STA.O) onlyOwner returns(bool){        
        sta = STA.C; 
        emit EVCL(msg.sender);    
        return true;
    }

    function open() public locked(LCK.U) sOf(STA.C) onlyOwner returns(STA){        
        sta = STA.O;     
        return sta;
    }

    function info() public view returns (address payable, uint256, uint8[11] memory, uint256,string memory, uint, STA, LCK, uint256){
        return (pO, pT, pP, pF, pN, rolls.length, sta, lck, pSM);
    }    

    function score(uint256 _rnd) private view returns(uint8, uint8, uint8, uint8, uint8, uint8){
        require(_rnd > 0, "pscrrnd");
        uint256  _n = _rnd;
        uint256  _d = 10;
        uint8[5] memory d = [0,0,0,0,0];
        uint8[6] memory m = [0,0,0,0,0,0];        

        d[0] = uint8(_n.mod(6).add(1));        
        m[(d[0]-1)] = uint8(m[(d[0]-1)]+1);        
        for (uint8 i=1;i<4;i++) {
            d[i] = uint8(_n.div(_d).mod(6).add(1));
            m[(d[i]-1)] = uint8(m[(d[i]-1)]+1);            
            _d = _d.mul(_d);
        }

        uint8 r = 0;
        if ((d[0]==6)&&(d[1]==6)&&(d[2]==6)&&(d[3]==6)&&(d[4]==6)){r=pP[0];}
        else if((m[0]==5)||(m[2]==5)||(m[3]==5)||(m[4]==5)||(m[5]==5)){r=pP[1];}
        else if((m[0]==4)||(m[1]==4)||(m[2]==4)||(m[3]==4)||(m[4]==4)||(m[5]==4)){r = pP[2];}
        else if(((m[0]==3)||(m[0]==2))||((m[1]==3)||(m[1]==2))||((m[2]==3)||(m[2]==2))||((m[3]==3)||(m[3]==2))||((m[4]==3)||(m[4]==2))||((m[5]==3)||(m[5]==2))){r=pP[3];}
        else if((m[0]>=1)&&(m[1]>=1)&&(m[2]>=1)&&(m[3]>=1)&&(m[4]>=0)){r=pP[4];} 
        else if((m[0]==0)&&(m[1]>=1)&&(m[2]>=1)&&(m[3]>=1)&&(m[4]>=1)&&(m[5]>=1)){r=pP[5];}
        else if((m[0]>=1)&&(m[1]>=1)&&(m[2]>=1)&&(m[3]>=1)&&(m[4]==0)){r=pP[6];}
        else if((m[0]==0)&&(m[1]>=1)&&(m[2]>=1)&&(m[3]>=1)&&(m[4]>=1)&&(m[5]==0)){r=pP[7];}
        else if((m[1]==0)&&(m[2]>=1)&&(m[3]>=1)&&(m[4]>=1)&&(m[5]>=1)){r=pP[8];}
        else if((m[0]==3)&&(m[1]==3)&&(m[2]==3)&&(m[3]==3)&&(m[4]==3)&&(m[5]==3)){r=pP[9];}
        else if((m[0]==2)||(m[2]==2)||(m[3]==2)||(m[4]==2)||(m[5]==2)){if(m[0].add(m[1]).add(m[3]).add(m[1]).add(m[4]).add(m[1]).add(m[5])==5){r=pP[10];}}
        else{r=0;} 

        return (r, d[0], d[1], d[2], d[3], d[4]);    
    } 
    
    function vpp(uint8[11] memory _p) private pure returns(bool){
            require(_p[0]  <= 90 && _p[0] > 0, "pvp0");
            require(_p[1]  < _p[0], "pvp1");
            require(_p[2]  < _p[1], "pvp2");
            require(_p[3]  < _p[2], "pvp3");
            require(_p[4]  < _p[3], "pvp4");
            require(_p[5]  < _p[4], "pvp5");
            require(_p[6]  < _p[5], "pvp6");
            require(_p[7]  < _p[6], "pvp7");
            require(_p[8]  < _p[7], "pvp8");
            require(_p[9]  < _p[8], "pvp9");
            require(_p[10] < _p[9], "pvp10");

            return true;
    }       
}