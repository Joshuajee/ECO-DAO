// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../libraries/LibGovernance.sol";

contract GovernanceFacet {
  IERC20 Ekotoken;
  bool init = false;

  // Modifier to ensure that user inputs an existing Proposal_ID
  modifier existingId(uint Proposal_ID) {
    LibGovernance.Tracker storage pt = LibGovernance.getProposalTracker();
    if (!(Proposal_ID <= pt.Proposal_Tracker || Proposal_ID > 0)) {
      revert("Invalid");
    } else {
      _;
    }
  }

  // A modifier that is used to ensure that a user can not input an empty string
  modifier noEmptiness(string memory name) {
    string memory a = "";
    if (keccak256(abi.encodePacked(name)) == keccak256(abi.encodePacked(a))) {
      revert("Can't be empty");
    } else {
      _;
    }
  }

  // modifier to protect against address zero
  modifier addressValidation(address a) {
    if (a == address(0)) {
      revert("Invalid address");
    } else {
      _;
    }
  }

  // modifier to ensure minimum token requirement is not zero
  modifier notZero (uint a) {
    if (a <= 0){
      revert("Can't be < zero");
    } else {
      _;
    }
  }

  // modifier to ensure the voter has enough Eko Stables to vote .
  modifier enoughEkoStables(address a) {
    LibGovernance.Tracker storage pt = LibGovernance.getProposalTracker();
    if (Ekotoken.balanceOf(a) < pt.Minimum_Token_Requirement) {
      revert("Insufficient Balance");
    } else {
      _;
    }
  }

  //Ekotoken contract address is passed on Governance contract initialization
  function intializeGovernance(
    address _token,
    uint min
  ) public addressValidation(_token) {
    if (init) revert("Already Initialized");
    Ekotoken = IERC20(_token);
    init = true;
    setMinimumTokenRequiremnent(min);
    emit LibGovernance.Minimum_Token_Requirement(min , msg.sender);
  }

  // function for admin to set the minimum token requirement
  function setMinimumTokenRequiremnent(
    uint min
    ) public notZero(min){
    LibGovernance.Tracker storage pt = LibGovernance.getProposalTracker();
    pt.Minimum_Token_Requirement = min * (10 ** 18) ;
    emit LibGovernance.Minimum_Token_Requirement(min , msg.sender);
  }

  // funtion to get the minimum Token requirement
  function getMinimumTokenRequirement() external view returns(uint){
    LibGovernance.Tracker storage pt = LibGovernance.getProposalTracker();
    return pt.Minimum_Token_Requirement;
  }

  // fucntion to create a new voting Proposal by Ekolance Admins.
  function newProposal(
    string calldata _name,
    uint _delayminutes,
    uint _delayHours,
    uint _votingDays
    ) external noEmptiness(_name) {
    LibGovernance.Tracker storage pt = LibGovernance.getProposalTracker();
    LibGovernance.Mappings storage mp = LibGovernance.getMappingStruct();
    pt.Proposal_Tracker += 1;
    uint Proposal_ID = pt.Proposal_Tracker;
    LibGovernance.Proposal memory _newProposal = LibGovernance.Proposal({
      name: _name,
      author: msg.sender,
      id: Proposal_ID,
      creationTime: block.timestamp,
      votingDelay: (_delayminutes * 60) + (_delayHours * 60 * 60) +
        block.timestamp,
      votingPeriod: (_delayminutes * 60) + (_delayHours * 60 * 60) + 
        (_votingDays * 60 *60 * 24) +
        block.timestamp,
      votesFor: 0,
      votesAgainst: 0,
      state : LibGovernance.State.notStarted
    });
    if (_newProposal.votingDelay <= block.timestamp){
      _newProposal.state = LibGovernance.State.ongoing;
      mp.ongoing[Proposal_ID] = true;
      mp.notStarted[Proposal_ID] = false;
    }else{
      mp.notStarted[Proposal_ID] = true;
    }
    mp.proposal[Proposal_ID] = _newProposal;     
    emit LibGovernance.New_Proposal(msg.sender, _newProposal, Proposal_ID);
  }

  // function to view an existing proposal
  function viewProposal(
    uint Proposal_ID
  )
    external
    view
    existingId(Proposal_ID)
    returns (LibGovernance.Proposal memory)
  {
    LibGovernance.Mappings storage mp = LibGovernance.getMappingStruct();
    return mp.proposal[Proposal_ID];
  }

  // function to get the number of existing proposals
  function getNumberOfProposals() external view returns (uint) {
    LibGovernance.Tracker storage pt = LibGovernance.getProposalTracker();
    return pt.Proposal_Tracker;
  }

  // function to delegate voting power for a particular proposal
  function addVotingDelegate(
    uint Proposal_ID,
    address _delegate
  ) external existingId(Proposal_ID) addressValidation(_delegate) {
    LibGovernance.Mappings storage mp = LibGovernance.getMappingStruct();
    mp.votingDelegate[Proposal_ID][msg.sender] = _delegate;
    emit LibGovernance.Add_Delegate(msg.sender, _delegate, Proposal_ID);
  }

  // function to view the delegate of an address on a particular proposal
  function viewDelegate(
    uint Proposal_ID,
    address _delegate
  )
    external
    view
    existingId(Proposal_ID)
    addressValidation(_delegate)
    returns (address)
  {
    LibGovernance.Mappings storage mp = LibGovernance.getMappingStruct();
    return mp.votingDelegate[Proposal_ID][_delegate];
  }

  // function to remove voting delegate
  function removeDelegate(uint Proposal_ID) external existingId(Proposal_ID) {
    LibGovernance.Mappings storage mp = LibGovernance.getMappingStruct();
    address _delegate = mp.votingDelegate[Proposal_ID][msg.sender];
    delete mp.votingDelegate[Proposal_ID][msg.sender];
    emit LibGovernance.Remove_Delegate(msg.sender, _delegate, Proposal_ID);
  }

  // function to vote on a proposal
  function voteFor(
    uint Proposal_ID
  ) external existingId(Proposal_ID) enoughEkoStables(msg.sender) {
    LibGovernance.Mappings storage mp = LibGovernance.getMappingStruct();
    if(mp.won[Proposal_ID] || mp.lost[Proposal_ID] || mp.stalemate[Proposal_ID] || mp.deleted[Proposal_ID]){
      revert("voting period over");
    }
    if (mp.proposal[Proposal_ID].votingDelay >= block.timestamp){
      revert("can't vote");
    } else if (mp.proposalVoter[Proposal_ID][msg.sender].voted){
      revert("already voted");
    }
    if(mp.proposal[Proposal_ID].votingPeriod <= block.timestamp){
      endVoting(Proposal_ID);
    }else{
    mp.proposalVoter[Proposal_ID][msg.sender].voted = true;
    mp.proposal[Proposal_ID].votesFor += 1;

    if (!mp.ongoing[Proposal_ID]){
      startVoting(Proposal_ID);
    }
    emit LibGovernance.Vote_For(msg.sender, Proposal_ID);
    }
  }
  
  // function to vote for a proposal as delegate.
  function voteForAsDelegate(
    uint Proposal_ID,
    address delegator
  )
    external
    existingId(Proposal_ID)
    enoughEkoStables(delegator)
    addressValidation(delegator)
  {
    LibGovernance.Mappings storage mp = LibGovernance.getMappingStruct();
    if(mp.won[Proposal_ID] || mp.lost[Proposal_ID] || mp.stalemate[Proposal_ID] ||  mp.deleted[Proposal_ID]){
      revert("voting period over");
    }
    if (
      (mp.proposal[Proposal_ID].votingDelay >= block.timestamp) ||
      (mp.votingDelegate[Proposal_ID][delegator] != msg.sender)
      ){
      revert("can't vote");
    } else if (mp.proposalVoter[Proposal_ID][delegator].voted){
      revert("already voted");
    }
    if(mp.proposal[Proposal_ID].votingPeriod <= block.timestamp){
      endVoting(Proposal_ID);
    }else{
    mp.proposalVoter[Proposal_ID][delegator].voted = true;
    mp.proposal[Proposal_ID].votesFor += 1;

    if (!mp.ongoing[Proposal_ID]){
      startVoting(Proposal_ID);
    }
    emit LibGovernance.Vote_For_As_Delegate(delegator, msg.sender, Proposal_ID);
    }
  }

  // function to vote against a proposal
  function voteAgainst(
    uint Proposal_ID
  ) external existingId(Proposal_ID) enoughEkoStables(msg.sender) {
    LibGovernance.Mappings storage mp = LibGovernance.getMappingStruct();

    if(mp.won[Proposal_ID] || mp.lost[Proposal_ID] || mp.stalemate[Proposal_ID] ||  mp.deleted[Proposal_ID]){
      revert("voting period over");
    }
    if (mp.proposal[Proposal_ID].votingDelay >= block.timestamp){
      revert("can't vote");
    } else if (mp.proposalVoter[Proposal_ID][msg.sender].voted){
      revert("already voted");
    }
    if(mp.proposal[Proposal_ID].votingPeriod <= block.timestamp){
      endVoting(Proposal_ID);
    }else{
    mp.proposalVoter[Proposal_ID][msg.sender].voted = true;
    mp.proposal[Proposal_ID].votesAgainst += 1;

    if (!mp.ongoing[Proposal_ID]){
      startVoting(Proposal_ID);
    }
    emit LibGovernance.Vote_Against(msg.sender, Proposal_ID);
    }
  }

  // function to vote against on a proposal as delegate.
  function voteAgainstAsDelegate(
    uint Proposal_ID,
    address delegator
  )
    external
    existingId(Proposal_ID)
    enoughEkoStables(delegator)
    addressValidation(delegator)
  {
    LibGovernance.Mappings storage mp = LibGovernance.getMappingStruct();
    if(mp.won[Proposal_ID] || mp.lost[Proposal_ID] || mp.stalemate[Proposal_ID] ||  mp.deleted[Proposal_ID]){
      revert("voting period over");
    }
    if (
      (mp.proposal[Proposal_ID].votingDelay >= block.timestamp) ||
      (mp.votingDelegate[Proposal_ID][delegator] != msg.sender)
      ){
      revert("can't vote");
    } else if (mp.proposalVoter[Proposal_ID][delegator].voted){
      revert("already voted");
    }
    if(mp.proposal[Proposal_ID].votingPeriod <= block.timestamp){
      endVoting(Proposal_ID);
    }else{
    mp.proposalVoter[Proposal_ID][delegator].voted = true;
    mp.proposal[Proposal_ID].votesAgainst += 1;

    if (!mp.ongoing[Proposal_ID]){
      startVoting(Proposal_ID);
    } 
    emit LibGovernance.Vote_For_As_Delegate(delegator, msg.sender, Proposal_ID);
    }
  }

  // function to delete the last proposal that has been created.
  function deleteProposal(
    uint Proposal_ID
  ) external existingId(Proposal_ID) {
    // require function caller is an ekolance admin
    LibGovernance.Mappings storage mp = LibGovernance.getMappingStruct();
    if (mp.proposal[Proposal_ID].votingDelay < block.timestamp) revert("Can't delete");
    delete mp.proposal[Proposal_ID];
    mp.notStarted[Proposal_ID] = false;
    mp.deleted[Proposal_ID] = true;
    mp.proposal[Proposal_ID].state = LibGovernance.State.deleted;
    emit LibGovernance.Delete_Proposal(msg.sender, Proposal_ID);
  }
  
  // returns the last 15 proposals that have not started
  function getNotStarted() external view returns(LibGovernance.Proposal[] memory ){
    LibGovernance.Proposal storage ps = LibGovernance.getProposalStruct();
    LibGovernance.Mappings storage mp = LibGovernance.getMappingStruct();
    LibGovernance.Tracker storage pt = LibGovernance.getProposalTracker();
    LibGovernance.Proposal[] memory Not_Started = new LibGovernance.Proposal[](15);
    bytes memory checker = bytes(Not_Started[14].name); 
    uint Proposal_ID = pt.Proposal_Tracker;
    uint count = 0;
    for (uint i= Proposal_ID; i > 0;i--){
      if(checker.length != 0){
        break;
      }
      if (mp.notStarted[i]){
        ps = mp.proposal[i];
        Not_Started[count] = mp.proposal[i];
        count++;
        continue;
      }
    }
    return Not_Started;
  }
  
  // returns the last 15 proposals that are ongoing
  function getOngoing() external view returns(LibGovernance.Proposal[] memory ){
    LibGovernance.Proposal storage ps = LibGovernance.getProposalStruct();
    LibGovernance.Mappings storage mp = LibGovernance.getMappingStruct();
    LibGovernance.Tracker storage pt = LibGovernance.getProposalTracker();
    LibGovernance.Proposal[] memory Ongoing = new LibGovernance.Proposal[](15);
    bytes memory checker = bytes(Ongoing[14].name); 
    uint Proposal_ID = pt.Proposal_Tracker;
    uint count = 0;
    for (uint i= Proposal_ID; i > 0;i--){
      if(checker.length != 0){
        break;
      }
      if (mp.ongoing[i]){
        ps = mp.proposal[i];
        Ongoing[count] = mp.proposal[i];
        count++;
        continue;
      }
    }
    return Ongoing;
  }

  // returns the last 15 proposals that have finshed and are won
  function getWon() external view returns(LibGovernance.Proposal[] memory ){
    LibGovernance.Proposal storage ps = LibGovernance.getProposalStruct();
    LibGovernance.Mappings storage mp = LibGovernance.getMappingStruct();
    LibGovernance.Tracker storage pt = LibGovernance.getProposalTracker();
    LibGovernance.Proposal[] memory Won = new LibGovernance.Proposal[](15);
    bytes memory checker = bytes(Won[14].name); 
    uint Proposal_ID = pt.Proposal_Tracker;
    uint count = 0;
    for (uint i= Proposal_ID; i > 0;i--){
      if(checker.length != 0){
        break;
      }
      if (mp.won[i]){
        ps = mp.proposal[i];
        Won[count] = mp.proposal[i];
        count++;
        continue;
      }
    }
    return Won;
  }

  // returns the last 15 proposals that have finshed and are lost
  function getLost() external view returns(LibGovernance.Proposal[] memory ){
    LibGovernance.Proposal storage ps = LibGovernance.getProposalStruct();
    LibGovernance.Mappings storage mp = LibGovernance.getMappingStruct();
    LibGovernance.Tracker storage pt = LibGovernance.getProposalTracker();
    LibGovernance.Proposal[] memory Lost = new LibGovernance.Proposal[](15);
    bytes memory checker = bytes(Lost[14].name); 
    uint Proposal_ID = pt.Proposal_Tracker;
    uint count = 0;
    for (uint i= Proposal_ID; i > 0;i--){
      if(checker.length != 0){
        break;
      }
      if (mp.lost[i]){
        ps = mp.proposal[i];
        Lost[count] = mp.proposal[i];
        count++;
        continue;
      }
    }
    return Lost;
  }

  // returns the last 15 proposals that have finshed and ended as a stalemate
  function getStalemate() external view returns(LibGovernance.Proposal[] memory ){
    LibGovernance.Proposal storage ps = LibGovernance.getProposalStruct();
    LibGovernance.Mappings storage mp = LibGovernance.getMappingStruct();
    LibGovernance.Tracker storage pt = LibGovernance.getProposalTracker();
    LibGovernance.Proposal[] memory Stalemate = new LibGovernance.Proposal[](15);
    bytes memory checker = bytes(Stalemate[14].name); 
    uint Proposal_ID = pt.Proposal_Tracker;
    uint count = 0;
    for (uint i= Proposal_ID; i > 0;i--){
      if(checker.length != 0){
        break;
      }
      if (mp.stalemate[i]){
        ps = mp.proposal[i];
        Stalemate[count] = mp.proposal[i];
        count++;
        continue;
      }
    }
    return Stalemate;
  }

  // function to start voting on a proposal
  function startVoting(
    uint Proposal_ID
  ) public existingId(Proposal_ID) {
      LibGovernance.Mappings storage mp = LibGovernance.getMappingStruct();
      if (mp.proposal[Proposal_ID].votingDelay <= block.timestamp){
        mp.ongoing[Proposal_ID] = true;
        mp.notStarted[Proposal_ID] = false; 
        mp.proposal[Proposal_ID].state = LibGovernance.State.ongoing;
      }
    }

  // function to endvoting
  function endVoting(
    uint Proposal_ID
  ) public existingId(Proposal_ID) {
    LibGovernance.Mappings storage mp = LibGovernance.getMappingStruct();
    if(mp.proposal[Proposal_ID].votingPeriod <= block.timestamp){
      if(mp.proposal[Proposal_ID].votesFor > mp.proposal[Proposal_ID].votesAgainst){
        mp.ongoing[Proposal_ID] = false;
        mp.won[Proposal_ID] = true;
        mp.proposal[Proposal_ID].state = LibGovernance.State.won;
        }else if (mp.proposal[Proposal_ID].votesFor < mp.proposal[Proposal_ID].votesAgainst){
          mp.ongoing[Proposal_ID] = false;
          mp.lost[Proposal_ID] = true;
          mp.proposal[Proposal_ID].state = LibGovernance.State.lost;
        }else if (mp.proposal[Proposal_ID].votesFor == mp.proposal[Proposal_ID].votesAgainst){
          mp.ongoing[Proposal_ID] = false;
          mp.stalemate[Proposal_ID] = true;
          mp.proposal[Proposal_ID].state = LibGovernance.State.stalemate;
        }
    }
  }

  
}
