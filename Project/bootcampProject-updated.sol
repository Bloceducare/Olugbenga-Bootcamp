pragma solidity ^0.5.0;

// Importing OpenZeppelin's SafeMath Implementation
import './safemath.sol';

contract CharityApp{

using SafeMath for uint256;
struct Charity{
uint id;
string name;
address payable acc;
string aboutUs;
}

//
struct Project{
    address payable creator;
    uint id;
    uint charityId;
    uint timeStarted;
    uint timeCompleted;
    uint maxNoOfDays; //the maximum days required to complete the project
    uint initialFund;
    uint target;
    uint projectBalance;
    bool active;
    bool successful;
    string description; // extra info about the project
}

struct Donation{
    uint id;
    uint projectId;
    uint amount;
    address payable donator;
    uint timeSent;
}

Charity[] public charities;     // holds all the registered charity
Project[] public projects;      //contains all projects created
Donation[] public donations;        //contains all donations made
mapping (address=>uint[]) public projectsStartedByUser;       //A mapping of user's address to all projects by user
mapping (address=>uint[]) public donationsByUser;               //A mapping of user's address to all donations by user
mapping (uint=>uint[]) public DonationsToAProject;              // All donations to a  particular project
mapping(address=>mapping(uint=>uint[])) public UserDonationsToAProject; // All donations by a user to a  particular project
mapping (address=>uint[]) public projectsIdDonatedToByUser;  //All projects a user has donated to.
uint public totalEthRaised;
uint public minimumPledgeAmount;    //The minimum amount required to fund a project
uint public noOfSuccessfulProjects;
uint public noOfCancelledProjects;
address payable public owner;

// Events to be emitted.
event newProject(uint id,uint time, address creator,uint charityId,string description);
event newCharity(uint id, string name,address acc, string aboutUs);
event donationAdded(uint id,uint projectId, uint amount, address donator,uint timeSent);
event projectCancelled(uint projectId,uint timeCancelled,uint charityId);
event projectSuccessful(uint projectId,uint timeSuccessful, uint projectBalance,uint charityId);

constructor()public{
    owner = msg.sender;
}

modifier onlyProjectCreator(uint _projectId){
   require(msg.sender == projects[_projectId].creator,"Only the project creator can call this function");
    _;
}
modifier onlyOwner(){
    require(msg.sender==owner);
    _;
}

// function to register a charity, returns the charity id.
function registerCharity(string memory _name,string memory _aboutUs) public returns(uint _id) {
Charity memory newcharity;
newcharity.name = _name;
newcharity.aboutUs = _aboutUs;
newcharity.acc = msg.sender;
_id = charities.push(newcharity).sub(1);
charities[_id].id = _id;
emit newCharity(_id, _name, msg.sender, _aboutUs);
}

/** Function to create a new project
 @param _percentToBeAdded percentage of the initial fund to be added.
 Calls the function payout() if the _percentToBeAdded is set to 0
 */
function createProject(uint _charityId, uint _percentToBeAdded, uint _maxNoOfDays,
 string memory _description) public payable returns(uint _id) {

require (msg.value >= minimumPledgeAmount);
require (_percentToBeAdded >= 0);
Project memory newproject;
newproject.charityId = _charityId;
newproject.creator = msg.sender;
newproject.timeStarted = now;
newproject.maxNoOfDays = _maxNoOfDays;
newproject.active = true;
newproject.successful = false;
newproject.initialFund = msg.value;
newproject.projectBalance += msg.value;
newproject.target = msg.value.add((_percentToBeAdded.mul(msg.value)).div(100));
newproject.description = _description;
totalEthRaised =  totalEthRaised.add(msg.value);
_id = projects.push(newproject).sub(1);
projects[_id].id = _id;
projectsStartedByUser[msg.sender].push(_id);

emit newProject(_id,now, msg.sender,_charityId, _description);

if(_percentToBeAdded == 0){
    payout(_id);
}
}

/**  function to contribute a donation to a project. returns the donation id.
    Calls the function payout() if the target has been met or if the maximum time
    has been reached.
*/
function contributeToProject(uint _projectId) public payable returns(uint _id){
    require(projects[_projectId].active);
    require(msg.sender!=projects[_projectId].creator);
    require(msg.value > 0);
    Donation memory newdonation;
    newdonation.projectId = _projectId;
    newdonation.amount = msg.value;
    newdonation.timeSent = now;
    newdonation.donator = msg.sender;
    projects[_projectId].projectBalance = projects[_projectId].projectBalance.add(msg.value);
    totalEthRaised = totalEthRaised.add(msg.value);
    _id = donations.push(newdonation).sub(1);
    donations[_id].id = _id;
    donationsByUser[msg.sender].push(_id);
    DonationsToAProject[_projectId].push(_id);
    UserDonationsToAProject[msg.sender][_projectId].push(_id);
    projectsIdDonatedToByUser[msg.sender].push(_projectId);

    emit donationAdded(_id,_projectId, msg.value, msg.sender,now);

    if((projects[_projectId].projectBalance >= projects[_projectId].target) || 
        (now >= projects[_projectId].timeStarted .add((projects[_projectId].maxNoOfDays.mul(1 days))))){
        payout(_projectId);
    }
}

/**
Cancels an existing project and calls the refundAll() function
 */
function cancelProject(uint _projectId) public onlyProjectCreator(_projectId) {
require(projects[_projectId].active);
uint _charityId = projects[_projectId].charityId;
refundAll(_projectId);
projects[_projectId].active = false;
projects[_projectId].successful = false;
noOfCancelledProjects++;
emit projectCancelled(_projectId, now, _charityId);
}

// Transfers fund to the charity address and tags the project successful.  
function payout(uint _projectId)private{
    uint _charityId = projects[_projectId].charityId;
    uint balance = projects[_projectId].projectBalance;
    charities[_charityId].acc.transfer(balance);
    projects[_projectId].projectBalance = 0;
    projects[_projectId].active = false;
    projects[_projectId].successful = true;
    projects[_projectId].timeCompleted = now;
    noOfSuccessfulProjects++;
    emit projectSuccessful(_projectId, now, balance, _charityId);

}

// function to refund the project creator and all the donors to the project.
function refundAll(uint _projectId) private{
    projects[_projectId].creator.transfer(projects[_projectId].initialFund);
    projects[_projectId].projectBalance = projects[_projectId].projectBalance.sub(projects[_projectId].initialFund);
    uint len = DonationsToAProject[_projectId].length;
    uint[]memory _DonationsToProjectId = new uint[](len);
    _DonationsToProjectId = DonationsToAProject[_projectId];
    for (uint index = 0; index < len; index++) {
       uint _donationId = _DonationsToProjectId[index];
       donations[_donationId].donator.transfer(donations[_donationId].amount);
       projects[_projectId].projectBalance =projects[_projectId].projectBalance.sub(donations[_donationId].amount);
    }
}

// A function which allows the owner to set the mimimun pledge amount
function adjustMinimumPledgeAmount (uint _newMinimum) public onlyOwner {
        require (_newMinimum > 0);
        minimumPledgeAmount = _newMinimum;
    }


function returnCharityDetails(uint _charityId)public view returns(string memory,address,string memory){
return (charities[_charityId].name, charities[_charityId].acc,charities[_charityId].aboutUs);

}

function returnProjectDetails(uint _projectId)public view returns 
(address,uint,uint,uint,uint){
    return(projects[_projectId].creator,projects[_projectId].charityId,
    projects[_projectId].timeStarted,projects[_projectId].timeCompleted,
    projects[_projectId].target);
}

function returnProjectDetails2(uint _projectId)public view returns 
(uint,bool,bool,string memory){
    return(projects[_projectId].projectBalance,projects[_projectId].active,
    projects[_projectId].successful,projects[_projectId].description);
}

function returnDonationDetails(uint _donationId) public view returns(
    uint,uint,address,uint){
        return(donations[_donationId].projectId,donations[_donationId].amount,
        donations[_donationId].donator,donations[_donationId].timeSent);
    }
    
function returnRemainingFundsNeeded(uint _projectId) public view returns(uint){
    require(projects[_projectId].active == true);
    return(projects[_projectId].target.sub(projects[_projectId].projectBalance));
}

function generalInfo() public view returns(uint,uint,uint,uint){
    uint noOfActiveProjects = projects.length.sub(noOfCancelledProjects.add(noOfSuccessfulProjects));
    return(charities.length,projects.length,donations.length,noOfActiveProjects);
}
function transferOwnership(address _newOwner)public onlyOwner{
owner = _newOwner;
}
function()external payable{
    
}

}
