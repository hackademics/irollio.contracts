// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./VRFService.sol";
import "@openzeppelin/contracts/payment/PullPayment.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/** @dev Pot Contract Description
    @dev Holds the balance of ether that players are trying to win (pot)
    @dev Pot Owner is address responsible for Seeding and Opening the contract (benefactor)
    @dev buy() is the payable call that accepts player entry fee and adds to balance (entry)
    @dev Request for a random uint256 number is made to LINK Verified Random Function (VRFService.sol wrapper) (shake)
    @dev Upon response of VRF number creation, number is converted to represent randomness as five six sided dice (roll)
    @dev Dice representation result is inspected for Jack Pot or other winning combos (score) 
    @dev Winning Combos cascade JACKPOT, FIVE OF A KIND, FOUR OF A KIND, FULL HOUSE, LARGE STRAIGHT(2), SMALL STRAIGHT(3), THREE OF A KIND, TWO PAIR
    @dev Player winnings are a percentage of the contract balance and Jack Pot payouts should always leave ten percent (win)
    @dev Pot Owners can set a custom payout at creation but these cannont be changed once Pot is opened.
    @dev Inspired by the tavern Shake A Day dice game, Pots can be created with an interval set between shakes(once per day, or tender shift)(DOS)
 */
 /** @dev TODOS
     @dev * Implement dynamic interval time between rolls
     @dev * Harden balance deposit, withdraw, tranfer
     @dev * Initializable and Reentrance guard
     @dev * Library for Scoring methods
     @dev * ECR20 Token deposit/swap
     @dev * Compound or AAVE integration for pot balance interest
     @dev * Allow Pot Owner to recover seed payment when applicable
     @dev * Pot Owner receives percent of fees, winnings, interest
     @dev * White listing of address for entry 
     @dev * bit shifting to compact stored data
  */
contract Pot is Ownable, PullPayment {    
    using SafeMath for *;
	using Address  for address;

    /** @dev Roll Struct: User, Die 1, Die 2, Die 3, Die 4, Die 5, Percent of Pot Won, Time stamp, VRF Request Id, VRF Random Numbers, Winnings */
    struct Roll { address usr; uint8 d1; uint8 d2; uint8 d3; uint8 d4; uint8 d5; uint8 pr; uint48 ts; bytes32 id; uint256 rand; uint256 w; }   
    
    /** @dev State, Lock */
    enum STA {I, O, C} 
    enum LCK {U, L} 

    /** @dev Pot Owner, Pot Name, Pot Created Timestamp, Pot Payout Array, Pot Total, Pot Entry Fee, Pot Seed Minimum, Pot Force Sixes for JackPot, Pot Roll Interval */
    address   payable public pO;
    string    public  pN;
    uint48    public  pTS;
    bool      public  pFS;
    uint8[11] public  pP; 
    uint256   public  pT;
    uint256   public  pF;
    uint256   public  pSM;
    uint256   public  pRI;
    LCK       public  lck;
    STA       public  sta;   
    Roll[]    public  rolls;
    
    /** @dev Buyins, Users last VRF Request ID */
    mapping (address => uint)    public bi;
    mapping (address => bytes32) public rids;

    /** @dev Seeded, BuyIn, Roll Saved, Pay Out, Pot Closed  */
    event EVSE(address indexed usr,uint a,uint ct);
    event EVBI(address indexed usr,uint a,uint ct);
    event EVRS(address indexed usr,uint rolls,bytes32 id,uint256 rand,uint256 w,uint8 pr);
    event EVPO(address indexed usr,uint256 w,uint256 pt,uint256 b);
    event EVCL(address indexed usr);

    /** @dev Is User Property Owner or Contract Owner, Is the able to roll based on interval */
    modifier isPO()   {require((msg.sender==pO)||(msg.sender==owner()),"ppo");_;}

    /** @dev INTIALIZE New Pot Contract for owner with defaults */
    constructor (address payable _po, uint8[11] memory _pp, uint256 _pf, string memory _pn, bool _pfs, uint256 _pRI) public{
        require(_po != address(0), "pcpo");
        require(_pf > 0, "pcpf");
        require(vpp(_pp)); 
        pO  = _po;
        pP  = _pp;
        pF  = _pf;
        pN  = _pn;
        pTS = uint48(block.timestamp);        
        pT  = 0;  
        pFS = _pfs;
        pRI = _pRI;
        sta = STA.I;
        lck = LCK.U;
    }

    /** @dev buy() - Deposits user payment to contract, initiates roll, increments user buy ins
        @param _s User Seed for VRF
        @return VRF Request Id
    */
    function buy(uint256 _s) external payable returns(bytes32){
        require(opened() && unlocked(),"pbuysl");
        require(allowed(), "");
        require(msg.value == pF, "pbipf");        
        lck = LCK.L;
            bi[msg.sender] = bi[msg.sender].add(msg.value);
            pT = pT.add(msg.value);        
            emit EVBI(msg.sender, msg.value, pT);
            rids[msg.sender] = new VRFService().request(_s);
        lck = LCK.U;  
        return rids[msg.sender];
    }

    /** @dev vrfR() - Callback from VRF Service - Converts _n to dice and scores - Pay called, Roll saved
        @param _id VRF Request Id - should match id sent to call on init
        @param _n  VRF Random Number uint256 
    */
    function vrfR(bytes32 _id, uint256 _n) external {
        require(_n > 0, "pvn");
        require(rids[msg.sender] == _id, "vrfrds");        
        uint256 w = 0;
        (uint8 per, uint8 d1, uint8 d2, uint8 d3, uint8 d4, uint8 d5) = score(_n);
        if(per > 0){ w = pay(per);}
        rolls[rolls.length - 1] = Roll(msg.sender, d1, d2, d3, d4, d5, per, uint48(block.timestamp), _id, _n, w);
        emit EVRS(msg.sender, rolls.length, _id, _n, w, per);  
    }

    /** @dev pay() - Takes the percentage won and transfers to winner 
        @param _p Percent of pot won to be paid to winner 
        @return Total Amount of Winnings 
    */
    function pay(uint8 _p) public returns(uint256) {
        require(opened() && unlocked(),"ppaysl");
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

    /** @dev seed() - Allow the pot to be seed by Pot Owner or Admin after creation
        @return Pot Total
    */
    function seed() public payable returns(uint256){
        require(opened() && unlocked(),"psedsl");
        require(msg.value >= pSM, "psppsm");
        lck = LCK.L;
            pT = pT.add(msg.value);
            sta = STA.O;
            emit EVSE(msg.sender, msg.value, pT);
        lck = LCK.U;
        return pT;
    }

    /** @dev score() - Converts Random Number to 5 six sided dice, checks dice for payout prize percent
        @param _rnd VRF Random Number unint256
        @return Prize Payout Percent, Die One, Die Two, Die Three, Die Four, Die Five
        @dev ** 0  : 66666 : JACKPOT
        @dev ** 1  : 11111 : FIVE OF A KIND
        @dev ** 2  : x1111 : FOUR OF A KIND
        @dev ** 3  : 11122 : FULL HOUSE
        @dev ** 4  : 12345 : LARGE STRAIGHT
        @dev ** 5  : 23456 : LARGE STRAIGHT
        @dev ** 6  : x1234 : SMALL STRAIGHT
        @dev ** 7  : x2345 : SMALL STRAIGHT
        @dev ** 8  : x3456 : SMALL STRAIGHT
        @dev ** 9  : xx111 : THREE OF A KIND
        @dev ** 10 : x1122 : TWO PAIR
    */
    function score(uint256 _rnd) private view returns(uint8, uint8, uint8, uint8, uint8, uint8){
        require(_rnd > 0, "pscrrnd");

        (uint8[5] memory d, uint8[6] memory m) = dice(_rnd);

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

    /** @dev dice() = Converts the VRF random unit256 and converts to 5 unique die
        @param _rnd VRF random number
        @return dice, matches                
     */
    function dice(uint256 _rnd) private pure returns(uint8[5] memory, uint8[6] memory){
       
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

        return (d, m);
    }        

    /** @dev close() - Set Pot status to Closed
        @return STA
     */
    function close() public onlyOwner returns(STA){    
        require(opened() && unlocked(),"pclssl");    
        sta = STA.C; 
        emit EVCL(msg.sender);    
        return sta;
    }
    
    /** @dev Contract State Helpers */
    function opened()   internal view returns(bool){return sta == STA.O;}
    function closed()   internal view returns(bool){return sta == STA.C;}
    function inited()   internal view returns(bool){return sta == STA.I;} 
    /** @dev Contract Lock Helpers*/
    function unlocked() internal view returns(bool){return lck == LCK.U;}
    function locked()   internal view returns(bool){return lck == LCK.L;}

    /** @dev allowed() - Determine if the user is allowed to play according to interval
        @return bool
    */
    function allowed() public view returns(bool){
        require(opened(),"pallwd"); 
        uint48 ts = usrTS();
        if(ts == 0){return false;}       
        return (ts +8 hours >= uint48(block.timestamp));
    } 

    /** @dev usrLast() - Gets the last roll for the user. 
        @return last roll by user time
    */
    function usrTS() public view returns(uint48) {
        require(opened(),"pusrts");
        for (uint i = rolls.length; i > 0; i--) {
            if(rolls[i].usr == msg.sender){
                return uint48(rolls[i].ts);
            }
        }
        return 0;
    }     

    /** @dev open() - Set Pot status to Open
        @return STA
     */
    function open() public onlyOwner returns(STA){  
        require(closed() && unlocked(),"pclssl"); 
        sta = STA.O;     
        return sta;
    }

    /** @dev info() - Output the details of the Pot 
        @return address payable, uint256, uint8[11] memory, uint256,string memory, uint, STA, LCK, uint256
     */
    function info() public view returns (address payable, uint256, uint8[11] memory, uint256,string memory, uint, STA, LCK, uint256){
        return (pO, pT, pP, pF, pN, rolls.length, sta, lck, pSM);
    }                          

    /** @dev vpp() - Ensures the validity of the cascading scoring of price percents
        @param _p Array of the prize percentages
        @return bool
    */
    function vpp(uint8[11] memory _p) private pure returns(bool){

        if(_p[0] > 90 && _p[0] == 0){return false;} 
        else if (_p[1] > _p[0]){return false;}
        else if (_p[2] > _p[1]){return false;}
        else if (_p[3] > _p[2]){return false;}
        else if (_p[4] > _p[3]){return false;}
        else if (_p[5] > _p[4]){return false;}
        else if (_p[6] > _p[5]){return false;}
        else if (_p[7] > _p[6]){return false;}
        else if (_p[8] > _p[7]){return false;}
        else if (_p[9] > _p[8]){return false;}
        else if (_p[10] > _p[9]){return false;}

        return true;
    }       
}