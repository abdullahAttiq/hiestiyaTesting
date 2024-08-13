// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Hiestiya {
    // Project struct definition
    struct Project {
        uint256 projectId;
        string projectName;
        uint256 totalCredits;
        uint256 soldCredits;
        uint256 availableCredits;
        uint256 creditPrice; // Price of one credit in ERC20 tokens
        address admin;
    }
    address public owner;

    // Marketplace struct definition
    struct MarketplaceListing {
        address seller;
        uint256 projectId;
        uint256 credits;
        uint256 pricePerCredit;
        bool isActive;
    }

    // Mappings to store projects, marketplace listings, and purchase records
    mapping(uint256 => Project) public projects;
    mapping(address => bool) public supportedTokens;
    mapping(uint256 => MarketplaceListing) public marketplaceListings;
    mapping(uint256 => mapping(address => uint256)) public purchaseRecords; // Tracks who bought how many credits for each project

    uint256 public nextProjectId = 0;
    uint256 public nextListingId = 0;

    // Constructor to set the initial owner
    constructor() {
        owner = msg.sender;
    }

    // Event declarations
    event ProjectCreated(
        uint256 indexed projectId,
        string projectName,
        uint256 totalCredits,
        uint256 creditPrice,
        address admin
    );
    event CreditsBought(
        uint256 indexed projectId,
        address indexed buyer,
        uint256 credits
    );
    event CreditsListed(
        uint256 indexed listingId,
        uint256 indexed projectId,
        address indexed seller,
        uint256 credits,
        uint256 pricePerCredit
    );
    event CreditsPurchasedFromListing(
        uint256 indexed listingId,
        address indexed buyer,
        uint256 credits,
        uint256 pricePerCredit
    );
    event CreditPriceUpdated(uint256 indexed projectId, uint256 newCreditPrice);
    event ListingCancelled(
        uint256 indexed listingId,
        address indexed seller,
        uint256 creditsReturned
    );

    // Function to create a project
    function createProject(
        string memory _projectName,
        uint256 _totalCredits,
        uint256 _creditPrice
    ) public returns (uint256) {
        require(_totalCredits > 0, "Total credits must be greater than zero");
        require(_creditPrice > 0, "Credit price must be greater than zero");
        nextProjectId++;

        projects[nextProjectId] = Project({
            projectId: nextProjectId,
            projectName: _projectName,
            totalCredits: _totalCredits,
            soldCredits: 0,
            availableCredits: _totalCredits,
            creditPrice: _creditPrice,
            admin: msg.sender
        });

        emit ProjectCreated(
            nextProjectId,
            _projectName,
            _totalCredits,
            _creditPrice,
            msg.sender
        );
        return nextProjectId;
    }

    // Function to buy credits directly from a project
    function buyCredits(
        uint256 _projectId,
        uint256 _credits,
        address _tokenAddress
    ) public returns (bool) {
        Project storage project = projects[_projectId];
        require(project.projectId != 0, "Project does not exist");
        require(
            _credits > 0 && _credits <= project.availableCredits,
            "Invalid credit amount"
        );
        require(supportedTokens[_tokenAddress] == true, "token not supported");

        require(_tokenAddress != address(0), "invalid token address");

        uint256 cost = _credits * project.creditPrice; // Calculate the cost based on the current credit price
        require(checkAllowance(_tokenAddress, cost), "no allowence");
        require(
            tokenTransfer(_tokenAddress, msg.sender, project.admin, cost),
            "payment Failed"
        );

        project.soldCredits += _credits;
        project.availableCredits -= _credits;
        purchaseRecords[_projectId][msg.sender] += _credits; // Record the purchase

        emit CreditsBought(_projectId, msg.sender, _credits);
        return true;
    }

    // Function for the project admin to update the credit price
    function updateCreditPrice(
        uint256 _projectId,
        uint256 _newCreditPrice
    ) public {
        Project storage project = projects[_projectId];
        require(project.projectId != 0, "Project does not exist");
        require(
            msg.sender == project.admin,
            "Only the project admin can update the credit price"
        );
        require(
            _newCreditPrice > 0,
            "New credit price must be greater than zero"
        );

        project.creditPrice = _newCreditPrice;

        emit CreditPriceUpdated(_projectId, _newCreditPrice);
    }

    // Function to list credits on the marketplace
    function listCreditsForSale(
        uint256 _projectId,
        uint256 _credits,
        uint256 _pricePerCredit
    ) public returns (uint256) {
        require(
            purchaseRecords[_projectId][msg.sender] >= _credits,
            "Not enough credits to list"
        );
        nextListingId++;

        marketplaceListings[nextListingId] = MarketplaceListing({
            seller: msg.sender,
            projectId: _projectId,
            credits: _credits,
            pricePerCredit: _pricePerCredit,
            isActive: true
        });

        purchaseRecords[_projectId][msg.sender] -= _credits; // Deduct credits from purchaseRecords

        emit CreditsListed(
            nextListingId,
            _projectId,
            msg.sender,
            _credits,
            _pricePerCredit
        );
        return nextListingId;
    }

    // Function to buy listed credits from the marketplace
    function buyCreditsFromListing(
        uint256 _listingId,
        uint256 _credits,
        address _tokenAddress
    ) public returns (bool) {
        MarketplaceListing storage listing = marketplaceListings[_listingId];
        require(listing.isActive, "Listing is not active");
        require(
            _credits > 0 && _credits <= listing.credits,
            "Invalid credit amount"
        );
        require(_tokenAddress != address(0), "invalid token Address");
        require(supportedTokens[_tokenAddress] == true, "unsupported token");

        uint256 totalCost = _credits * listing.pricePerCredit;
        require(checkAllowance(_tokenAddress, totalCost), "no allownce");
        require(
            tokenTransfer(_tokenAddress, msg.sender, listing.seller, totalCost),
            "trx failed"
        );

        listing.credits -= _credits;
        purchaseRecords[listing.projectId][msg.sender] += _credits; // Record the purchase

        if (listing.credits == 0) {
            listing.isActive = false;
        }

        emit CreditsPurchasedFromListing(
            _listingId,
            msg.sender,
            _credits,
            listing.pricePerCredit
        );
        return true;
    }

    // Function to cancel a marketplace listing
    function cancelListing(uint256 _listingId) public returns (bool) {
        MarketplaceListing storage listing = marketplaceListings[_listingId];
        require(listing.isActive, "Listing is not active");
        require(
            msg.sender == listing.seller,
            "Only the seller can cancel the listing"
        );

        listing.isActive = false;
        purchaseRecords[listing.projectId][listing.seller] += listing.credits; // Return credits to the seller

        emit ListingCancelled(_listingId, msg.sender, listing.credits);
        return true;
    }

    function tokenTransfer(
        address tokenAddress,
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        IERC20 token = IERC20(tokenAddress);

        require(token.transferFrom(from, to, amount), "trx fail");

        return true;
    }

    function checkAllowance(
        address tokenAddress,
        uint256 amount
    ) internal view returns (bool) {
        IERC20 token = IERC20(tokenAddress);
        require(
            token.allowance(msg.sender, address(this)) >= amount,
            "Insufficient allowance"
        );
        return true;
    }

    function addSupportedToken(address _tokenAddress) public {
        require(msg.sender == owner, "only owner have access");
        require(_tokenAddress != address(0), "invalid token address");
        require(supportedTokens[_tokenAddress] = true, "token already exist");

        supportedTokens[_tokenAddress] = true;
    }

    function editProjectName(
        uint256 _projectId,
        string memory newName
    ) public returns (bool) {
        require(_projectId < nextProjectId, "projectId doesnt exsist");
        Project storage project = projects[_projectId];

        require(
            project.admin == msg.sender,
            "only owner have access"
        );
        project.projectName= newName;
        return true;
    }
}
