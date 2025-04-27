
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

contract CrowdFunding{

 struct Campaing{
        uint256 campaingId; //αναγνωριστικός αριθμός καμπάνιας 
        address entrepreneur; //διέυθυνση επιχχειρηματία 
        string title; //όνομα καμπάνιας
        uint256 pledgeCost; // κόστος μετοχής 
        uint256 pledgesNeeded; // αριθμός μετοχών που απαιτούνται
        uint256 pledgesCount; // συνολικές δεσμεύσεις
        bool fulfilled; // αν ολοκληρώθηκε η καμπάνια 
        bool cancelled; // αν ακυρώθηκε η καμπάνια
        address[] backers; //πινακας επενδυτών
        mapping (address => uint256) backerPledges; // Πινακας ποσων που εχουν επενδυσει οι επενδυτες
 }

 address public owner;

 mapping (uint256=>Campaing) public campaings;
 mapping (address =>bool) public banned;
 address[] private bannedAddresses;
 bool private Destroyed = false;
 

//αριθμός καμπανιών και του fee
uint256 private  nextCampaingId=1;
uint256 private  CampaingFee = 0.02 ether;


//MODIFIERS
 modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

//modifier για τον owner
modifier NotOwner(){
    require(msg.sender!=owner,"Owner cannot call this.");
    _;
}

//modifier για έλεγχο banned διεύθυνσης 
modifier notBanned{
    require(!banned[msg.sender],"Address is Banned.");
    _;
}

//modifier για αν το fee είναι αρκετό
modifier ValidFee(){
    require(msg.value>=CampaingFee,"Not enough fee.");
    _;
}

//modifier για αν υπάρχει ονομα-τίτλος σε καμπάνια
modifier ValidTitle(string memory atitle){
    require(bytes(atitle).length>0,"Title is required");
    _;
}

//modifier για αν το κόστος μετοχής είναι θετικό
modifier ValidPleadges(uint256 apledgeCost){
    require(apledgeCost>0,"Pledge cost should be more than 0");
 _;
}

//modifier για το αν ο αριθμός το μετoχών που χρειάζεται μια καμπάνια να ολοκληρωθέι είναι θετικός 
modifier ValidPleadgesCount(uint256 apledgeNeeded){
    require(apledgeNeeded>0,"Pledge should be more than 0 ");
    _;
}

//mofifier για το αν υπάρχει μια καμπάνια
modifier CampaingExists(uint256 acampaingId){
 require(campaings[acampaingId].campaingId !=0,"Campaing does not exist.");
    _;
}

//modifier για το έχει ολοκληρωθεί μια καμπάνια  η αν έχει ακυρωθεί 
modifier CampaingNotFullfilledOrCancelled(uint256 acampaingId){
    require (!campaings[acampaingId].fulfilled,"Campaing is fulfilled.");
    require (!campaings[acampaingId].cancelled,"Campaing is cancelled.");
    _;
}

//modifier αν οι μετοχές είναι σωστές 
modifier ValidShares(uint256 purchased_shares){
    require(purchased_shares>0,"Shares must be more than 0.");
    _;
}

//modifier για το αν μια πληρωμή είναι σωστή
modifier CorrectPayment(uint256 acampaingId,uint256 purchased_shares){
    require(msg.value==purchased_shares*campaings[acampaingId].pledgeCost,"Incorrect amount sent");
    _;
}

//modifier για ελεγχο εαν η καμπανια εχει φτασει τον απιτουμενο αριθμο που χρειαζεται
modifier CampaingHasEnoughPledges(uint256 acampaingId) {
    require(
        campaings[acampaingId].pledgesCount >= campaings[acampaingId].pledgesNeeded,
        "This campaing has not reached the needed pledges."
    );
    _;
}

//modifier για την ακύρωση καμπάνιας απο επιχειρηματία ή ιδιοκτήτη
modifier EntrepreneuerOrOwner(uint256 acampaingId){
    require(msg.sender==campaings[acampaingId].entrepreneur || msg.sender==owner,"Not Authorized.");
    _;
}

//mofidier για ακυρωμένο campaing 
modifier RequireCancelledCampaing(uint256 campaingId){
    require (campaings[campaingId].cancelled,"Campaing is not cancelled");
    _;
}

//mofidier για ελεγχο εγκυρης διευθυνσης
modifier ValidAddress(address _address){
    require(_address != address(0), "Invalid address");
    _;
}

//mofifier για έλεγχο αν είναι κατεστραμένο το συμβόλαιο
modifier isDestroyedContract(){
    require(!Destroyed,"Contract is destroyed.");
    _;
}

//Constructor
constructor(){
    owner=msg.sender;
}

//EVENTS
//event για όταν δημιουργέιται μια καμπάνια
event CampaingCreated(uint256 campaignId,address entrepreneur,string title);
//event για οταν την χρηματοδότηση μιας καμπάνιας δηλαδη αγορά μετοχών 
event SharesPurchased(uint256 acampaingId,address backer,uint256 purchased_shares);
//event για την ακύρωση μιας καμπάνιας 
event CancelledCampaing(uint256 acampaingId);
//event για αποζημίωση επενδυτή
event RefundInvestor(uint256 campaingId,address entrepreneuer,uint256 amount);
//event για ολοκλήρωση καμπάνιας
event CompletedCampaing(uint256 campaingId);
//event για αποκλεισμο επιχειρηματία 
event AddressBanned(address user_address);
//event για καταστροφη συμβολαιου
event ContractDestroy(bool Destroyed);

//1η λειτουργία δημιουργία μιας νέας καμπάνιας 
function CreateCampaing(string memory atitle,uint256 apledgeCost,uint256 apledgeNeeded) public payable
    NotOwner
    notBanned 
    ValidFee
    isDestroyedContract
    ValidTitle(atitle)
    ValidPleadges(apledgeCost)
    ValidPleadgesCount(apledgeNeeded){

        //αποθήκευση της καμπάνιας στο mapping
        Campaing storage newCampaing = campaings[nextCampaingId];
        newCampaing.campaingId=nextCampaingId;
        newCampaing.entrepreneur=msg.sender;
        newCampaing.title=atitle;
        newCampaing.pledgeCost=apledgeCost;
        newCampaing.pledgesNeeded=apledgeNeeded;
        newCampaing.fulfilled=false;

        //event για την δημιουργία της καμπάνιας και αύξηση τπυ αριθμού για την επόμενη καμπάνια 
        emit CampaingCreated(nextCampaingId,msg.sender,atitle);
        nextCampaingId++;
}

//2η λειτουργία χρηματοδότηση καμπανιας 
function PurchasedShares(uint256 acampaingId,uint256 purchased_shares) public payable 
    notBanned
    isDestroyedContract
    CampaingExists(acampaingId)
    CampaingNotFullfilledOrCancelled(acampaingId)
    ValidShares(purchased_shares)
    CorrectPayment(acampaingId,purchased_shares)
    {

        Campaing storage campaing = campaings[acampaingId];

        //αύξηση του αριθμόυ των μετοχών που αγόρασσε ο επενδυτήσ και αποθήκευση του στον πίνακα της καμπάνιας που με τους επενδυτές
        campaing.pledgesCount += purchased_shares;
        campaing.backers.push(msg.sender);
        campaing.backerPledges[msg.sender] += msg.value; //ενημέρωση των μετοχών του επενδυτή 

        
        
        
        emit SharesPurchased(acampaingId, msg.sender, purchased_shares);
}

//λειτουργία που επιστρέφει στον χρήστη πόσα wei (msg.value) πρέπει να πλρώσει ώστε να αγοράσει τον πλήθος των μετοχών που εχει επιλέξει
function getRequiredPayment(uint256 acampaingId, uint256 purchased_shares) public view isDestroyedContract returns (uint256)  {
    return purchased_shares * campaings[acampaingId].pledgeCost;
}

//3η λειτουργία ακυρωση καμπάνιας
function CancelCampaing(uint256 acampaingId) public 
    CampaingExists(acampaingId)
    CampaingNotFullfilledOrCancelled(acampaingId)
    EntrepreneuerOrOwner(acampaingId)
    isDestroyedContract{

        Campaing storage campaing = campaings[acampaingId];

        //δήλωση ότι η καμπάνια είναι ακυρωμένη
        campaing.cancelled=true;
        emit CancelledCampaing(acampaingId);
    }

//4η λειτουργία αποζημίωση επενδυτή 
function InvestorRefund() public {

    uint256 totalRefundAmount=0; //μηδενίζω το συνολικο ποσο επιστροφής

    for (uint256 i = 1; i < nextCampaingId; i++) {
        Campaing storage c = campaings[i];

        if (c.cancelled) {
            uint256 refundAmount = c.backerPledges[msg.sender];
            if (refundAmount > 0) {
                (bool done, ) = payable(msg.sender).call{value: refundAmount}("");
                require(done, "Refund failed for campaign.");
                c.backerPledges[msg.sender] = 0;
                totalRefundAmount += refundAmount;

                emit RefundInvestor(i, msg.sender, refundAmount);
            }
        }
    }
    require(totalRefundAmount > 0, "No refunds to process.");
 }

//5η λειτουργία ολοκλήρωση της καμπάνιας 
function CompleteCampaing(uint256 acampaingId) public 

    CampaingExists(acampaingId)
    CampaingNotFullfilledOrCancelled(acampaingId)
    EntrepreneuerOrOwner(acampaingId)
    CampaingHasEnoughPledges(acampaingId)
    isDestroyedContract{

        Campaing storage c = campaings[acampaingId];

        //υπολογισμός των κερδών 
        uint256 totalFunds = c.pledgesCount * c.pledgeCost; 
        uint256 fundsToEntreprenuer = (totalFunds*80)/100;

        //στέλνω τα κέρδη στον επιχειρηματία 
        (bool done,)=payable(c.entrepreneur).call{value:fundsToEntreprenuer}("");
        require(done,"Funds to entrepreneur failed");
        c.fulfilled=true;  //δηλώνω οτι η καμπάνια ολοκληρώθηκε

        emit CompletedCampaing(acampaingId);

    }

//λειτουργια που εμφανιζει τις ενεργές καμπάνιες,η solidity δεν με αφηνει να επιστρεψω struct mappings οποτε απλα βρίσκω ποιεσ ειναι
//οι ενεργείσ καμπάνιες,για να δω τα στοιχεία τους καλώ την campaings
function getActiveCampaings() public view isDestroyedContract returns (uint256[] memory){
    
    //βρίσσκω των αριθμο των ενεργων καμπανιων 
    uint256 activeCount = 0;
    for (uint256 i =1; i < nextCampaingId ; i++){
        if (!campaings[i].cancelled && !campaings[i].fulfilled)
            activeCount++;
    }

    //δημιουργω εναν πινακα με τισ ενεργείς καμπανιες μεγέθουσ του αριθμόυ που βρήκα πανω
    uint256[] memory activeCampaings =  new uint256[](activeCount);
    uint256 active=0;

    for (uint256 i=1;i<nextCampaingId;i++){
        if (!campaings[i].cancelled && !campaings[i].fulfilled){
            activeCampaings[active]=i;
            active++;
        }
    }
    return activeCampaings;
}

//λειτουργία για να βρω ολοκληρωμένεσ καμπάνιες, παλι το ίδιο οπως την προηγουμενη συναρτηση σχολια 230,231
function getCompletedCampaings() public view isDestroyedContract returns(uint256[] memory){

    //βρίσκω αριθμό ολοκληρωμένων καμπανίων
    uint256 completedCount=0;
    for(uint256 i=1;i<nextCampaingId;i++){
        if (campaings[i].fulfilled)
            completedCount++;
    }

    uint256[] memory completedCampaings = new uint256[](completedCount);
    uint256 completed=0;

     for(uint256 i=1;i<nextCampaingId;i++){
        if (campaings[i].fulfilled){
            completedCampaings[completed]=i;
            completed++;
        }        
    }
    return completedCampaings;
}

//λειτουργία που εμφανίζει ακυρωμένες καμπάνιες , ιδια λογική όπωσ τισ δύο προηγούμενες
function getCancelledCampaings() public view returns (uint256[] memory){
    uint256 cancelledCount=0;
    for(uint256 i=1;i<nextCampaingId;i++){
        if (campaings[i].cancelled)
            cancelledCount++;
    }

    uint256[] memory cancelledCampaings = new uint256[](cancelledCount);
    uint256 cancelled=0;

    for(uint256 i=1;i<nextCampaingId;i++){
        if (campaings[i].cancelled){
            cancelledCampaings[cancelled]=i;
            cancelled++;
        }
    }
    return cancelledCampaings;
}

//λειτουργια που εμφανιζει την λιστα των banned διευθυνσχεων
function getBannedAddress() public view  isDestroyedContract returns (address[] memory) {
    return bannedAddresses;
   
    }

//λειτουργια για ερώτηση που για μια καμπανια ποιοι είναι οι επενδυτες και πόσες μετοχές έχει ο καθένας
function getBackersAndShares(uint256 acampaingId) public view 
    CampaingExists(acampaingId) 
    returns(address[] memory,uint256[] memory){

        Campaing storage c = campaings[acampaingId];
        uint256 backerCount = c.backers.length; //μετρητης μετόχων 

        address[] memory backers = new address[](backerCount); //πινκας επενδυτων της καμπάνιας
        uint256[] memory shares = new uint256[](backerCount);  // πινακας αριθμου μετοχών των επενδυτων στην καμπανια

        //υπολογισμός των μετοχών κάθε επενδυτή
        for (uint256 i =0;i<backerCount;i++){
            address b = c.backers[i];
            backers[i] = b;
            shares[i]= c.backerPledges[b] / c.pledgeCost;
        }
        return (backers,shares);
}

//λειτουργία που εμφανίζει τα fees απο τισ καμπανιες
function getContractFees() public view isDestroyedContract returns (uint256){
    uint256 totalFees = 0;

    //υπολογισμός και προσθήκη των fees απο τις εγγραφές καμπάνιων
    uint256 registrationFees = (nextCampaingId-1) * CampaingFee ;
    totalFees = totalFees+registrationFees;

    //υπολογισμο και προσθήκη των fees απο ολοκληρωμένες καμπανιες
    for (uint256 i=1;i<nextCampaingId;i++) {
        if (campaings[i].fulfilled ) {
            Campaing storage c = campaings[i];
            uint256 totalFunds = c.pledgesCount * c.pledgeCost;
            uint256 campaingFee = (totalFunds*20) / 100;
            totalFees = totalFees + campaingFee;
        }
    }
    return totalFees;
}

//λειτουργια ιδιοκτητη που αποσύρει τις κρατήσεις απο τισ καμπάνιες 
function WithdrawOwnerFees() public onlyOwner  {
    uint256 totalEarnings = 0;

    //υπολογισμός και προσθήκη των fees απο τις εγγραφές καμπάνιων
    uint256 registrationFees = (nextCampaingId-1) * CampaingFee ;
    totalEarnings = totalEarnings+registrationFees;

    //υπολογισμο και προσθήκη των fees απο ολοκληρωμένες καμπανιες
    for (uint256 i=1;i<nextCampaingId;i++) {
        if (campaings[i].fulfilled ) {
            Campaing storage c = campaings[i];
            uint256 totalFunds = c.pledgesCount * c.pledgeCost;
            uint256 campaingFee = (totalFunds*20) / 100;
            totalEarnings = totalEarnings + campaingFee;
        }
    }
        require(address(this).balance >= totalEarnings, "Insufficient contract balance");
        (bool done,)= payable(owner).call{value: totalEarnings}("");
        require(done,"Transfer Failed.");
}

//λειτουργια αποκλεισμου επιχειρηματία 
function banAddress(address user_address) public
    isDestroyedContract 
    onlyOwner
    ValidAddress(user_address){

        banned[user_address]=true;
        bannedAddresses.push(user_address);
        emit AddressBanned(user_address); 
}

//λειτουργια αλλαγης ιδιοκτήτη 
function ChangeOwnership(address new_owner_address) public 
    isDestroyedContract
    onlyOwner
    ValidAddress(new_owner_address) {
        owner=new_owner_address;
    }

//λειτουργία εμφάμισης σε ποιέσ καμπαννιεσ έχει επενδύσει ενας backer και τα ποσά
function getBackerInvestments(address backer_address) public view  ValidAddress(backer_address)
    returns (uint256[] memory, uint256[] memory)
    {

        uint256 count =0;
        for (uint256 i=1;i<nextCampaingId;i++)
            if (campaings[i].backerPledges[backer_address]>0)
            count++;
        
        uint256[] memory backer_campaignId = new uint256[](count);
        uint256[] memory backer_amounts = new uint256[](count);
           uint256 index = 0;

        for (uint256 i = 1; i < nextCampaingId; i++) {
            uint256 pledge = campaings[i].backerPledges[backer_address];
            if (pledge > 0) {
                backer_campaignId[index] = i;
                backer_amounts[index] = pledge;
                index++;
            }
        }

        return (backer_campaignId,backer_amounts);

    }

//λειτουργια καταστροφης συμβολαιου 
function DestroyContract() public onlyOwner isDestroyedContract {
    Destroyed = true;
    for (uint256 i = 1; i<nextCampaingId;i++) {
        Campaing storage c = campaings[i];
        if (!c.cancelled && !c.fulfilled) {
             c.cancelled = true;
             }
             emit ContractDestroy(Destroyed);
   
}}


//λειτουργία που επιστρέφει τα στοιχεία μιας καμπάνιας δίνωντας το id
function getCampaing(uint256 campaingId) public view returns (
    string memory title,
    uint256 pledgeCost,
    uint256 pledgesCount,
    uint256 pledgesNeeded,
    address entrepreneur,
    bool fulfilled
) {
    Campaing storage c = campaings[campaingId];
    return (
        c.title,
        c.pledgeCost,
        c.pledgesCount,
        c.pledgesNeeded,
        c.entrepreneur,
        c.fulfilled
    );
}

//λειτουργία που επιστρέφει το ποσό των μετοχων που έχει ενασ χρήστης σε μία καμπάνια
function getUserPledges(uint256 campaingId, address user) public view returns (uint256) {
    return campaings[campaingId].backerPledges[user];
}


}