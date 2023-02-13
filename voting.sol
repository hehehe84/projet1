// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {

    //Liste des évènements nécessaires
    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint256 proposalId);
    event Voted (address voter, uint256 proposalId);

    //Liste des struct nécessaires
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint256 votedProposalId;
    }

    struct Proposal {
        string description;
        uint256 voteCount;
    }

    //Liste des etats 
    
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    WorkflowStatus public status;

    /* Début du code */

    //Création du mapping des voteurs

    mapping (address => Voter) voters;

    /*👇Création liste de propositions*/

    Proposal[] internal proposals;



    /*Création des modifiers pour simplifier le corps des fonctions*/

    modifier RegVoter {
        require(status == WorkflowStatus.RegisteringVoters, "Sorry, we can call this function only during vote registration.");
        _;
    }

    modifier StartProp {
        require(status == WorkflowStatus.ProposalsRegistrationStarted, "Sorry, we can call this function only during proposal registration.");
        _;
    }

    modifier EndProp {
        require(status == WorkflowStatus.ProposalsRegistrationEnded, "Sorry, we can call this function only at the end of proposal registration.");
        _;
    }

    modifier StartVot {
        require(status == WorkflowStatus.VotingSessionStarted, "Sorry, we can call this function only during voting session.");
        _;
    }

    modifier EndVot {
        require(status == WorkflowStatus.VotingSessionEnded, "Sorry, we can call this function only at the end of voting session."); 
        _;
    }

    modifier TallyVot {
        require(status == WorkflowStatus.VotesTallied, "Sorry, we can call this function only during Tally session.");
        _;
    }

    modifier RegisteredV {
        require(voters[msg.sender].isRegistered, "Voter is not registered in the Whitelist");
        _;
    }

    modifier waitAdmin {
        require(ADM == true, "Wait that the administrator tally the votes.");
        _;
    }

    modifier waitAdmin2 {
        require(ADM2 == true, "Wait that the administrator randomize the votes.");
        _;
    }




    /*Création des fonctions permettant au 
    modérateur de changer les états du vote.
    👉 A_ dans l'entête pour plus de visibilité 
    dans l'execution du compte */
    

    function A1_startRegistering() public onlyOwner {
        status = WorkflowStatus.RegisteringVoters;
    }

    function A2_startProposals() public onlyOwner RegVoter{
        status = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, status);
    }

    function A3_endProposals() public onlyOwner StartProp{
        status = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, status);
    }

    function A4_startVoting() public onlyOwner EndProp{
        status = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, status);
    }

    function A5_endVoting() public onlyOwner StartVot{
        status = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, status);
    }

    function A6_tallyVotes() public onlyOwner EndVot{
        status = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, status);
    }



    /*👇 L'administrateur peut ajouter des addresses dans la whitelist : "isRegistered"
    A0_Registeringvoters => praticiter pour exécuter le code*/

    function A11_RegisteringVoters(address _addr) public onlyOwner RegVoter{
        require(!voters[_addr].isRegistered, "Already in the Whitelist");

        /*👇Modification dans la structure du voteur*/
        voters[_addr].isRegistered = true;
        voters[_addr].hasVoted = false;
        voters[_addr].votedProposalId = 0;

        emit VoterRegistered(_addr);
    }

    /*
    👇 Nous pouvons entrer des propositions dans une liste . 
    /!\/!\/!\
    Bien penser à entrer l'administrateur dans la registering list!!!! 😡😡😡
    /!\/!\/!\
    */

    function B1_SubmitProposals(string memory _Prop) public StartProp RegisteredV{
        proposals.push(Proposal({description : _Prop, voteCount : 0}));
        emit ProposalRegistered(proposals.length-1);
    }


    /*Création de Deux arrays que l'on peut consulter 
    pour voir les propositions liées à leurs Ids 👇👇👇*/

    uint256[] proposalNumb;
    string[] allProposals;

    /*On peut choisir une autre proposition pour la fonction ci-dessous (le problème étant que cette fonction n'est pas en "view"
    car je delete les tableaux précédent. Je n'ai pas réussi à avoir */

    function B2_getProposals() public returns(uint256[] memory, string[] memory) {
        delete proposalNumb;      //Ces lignes servent à ne pas avoir des tableaux qui s'ecrivent à l'infini quand on appelle 
        delete allProposals;      //un grand nombre de fois la fonction.
        for (uint256 i=0; i < proposals.length; i++){
            proposalNumb.push(i);
            allProposals.push(proposals[i].description);
        }
        return (proposalNumb, allProposals);
    }

    /*👇L'electeur choisit l'id de la proposition qui le sied.*/

    function C1_voteProposal(uint256 _proposalId) public StartVot RegisteredV{
        require(voters[msg.sender].hasVoted == false, "Voter already voted");

        proposals[_proposalId].voteCount ++;

        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposalId;
    }



    /*👇Fonction retournant les propositions (descriptifs) une fois que les sessions de votes sont 
    terminées et le décompte de associés aux propositions !
    Je pensais mettre une options pour observer le décompte pendant la session de vote mais ceci ne respecte 
    pas le code "confiance" car fausse la démocratie.*/

    uint256[] totalVotes;
    string[] allProposals2;
    uint256[] idProposal;

    //👇 Sert à ce que les votant aient accès aux résultats.
    bool ADM = false;

    function D1_Total() public onlyOwner TallyVot returns(uint256[] memory, string[] memory, uint256[] memory) {
        delete totalVotes;
        delete allProposals2;
        delete idProposal;
        uint256 highVote = 0;
        for (uint256 i=0; i < proposals.length; i++) {
            if (proposals[i].voteCount > highVote){
                if(totalVotes.length >= 1) {      //Si le tableau contient plus de 1 élément :
                    for (uint256 j = 0; j < totalVotes.length; j++){
                        delete totalVotes;
                        delete allProposals2;
                        delete idProposal;
                    }
                    totalVotes.push(proposals[i].voteCount);
                    allProposals2.push(proposals[i].description);
                    idProposal.push(i);

                        highVote = proposals[i].voteCount;
                } else {            //Si le tableau contient 1 élément
                    totalVotes.pop;
                    allProposals2.pop;
                    idProposal.pop;

                    totalVotes.push(proposals[i].voteCount);
                    allProposals2.push(proposals[i].description);
                    idProposal.push(i);

                    highVote = proposals[i].voteCount;
                }
            } else if (proposals[i].voteCount == highVote) {
                totalVotes.push(proposals[i].voteCount);
                allProposals2.push(proposals[i].description);
                idProposal.push(i);
            }
        }
        ADM = true;
        return (totalVotes, allProposals2, idProposal);
    }

    /*☝️ADM si dessus sert à ce que l'utilisateur ait accès à showResult (via modifier waitAdmin définit avant).👇*/

    function D2_showResult() view public TallyVot waitAdmin returns(uint256[] memory, string[] memory, uint256[] memory){
        return (totalVotes, allProposals2, idProposal);
    }

    /*☝️Retourne bien les différentes propositions qui gagnantes. (Attention, elle retourne aussi des égalitées.)*/

    /*Proposition d'amélioration :
    Fonction choisissant au hasard une des proposition a égalité (dans la liste allProposals)
    Via une fonction aléatoire avec keccak même si il s'agit d'un random perfectible, on présume qu'il est suffisant dans notre 
    exemple.*/

    uint256 chosenVote;
    string chosenProp;
    uint256 chosenId;
    bool ADM2 = false;


    function E1_random_choice() public onlyOwner TallyVot returns(uint256, string memory, uint256){

        uint256 Length = totalVotes.length;
        uint256 rest = (uint256(keccak256(abi.encodePacked(Length, block.timestamp))) % (Length-1));
        chosenVote = (totalVotes[rest]);
        chosenProp = (allProposals2[rest]);
        chosenId = (idProposal[rest]);
        ADM2 = true;
        return(chosenVote, chosenProp, chosenId);
    }

    /*☝️👇Même structure que nos précédentes fonctions (appelées D)*/

    function E2_showFinalResult() view public TallyVot waitAdmin2 returns(uint256, string memory, uint256){
        return(chosenVote, chosenProp, chosenId);
    }

}
