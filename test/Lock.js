const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
//const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require('hardhat');

describe("Hiestiya Contract", function () {
  async function deployContractsFixture() {
    const [owner, admin, buyer, seller, otherAccount] = await ethers.getSigners();

    // Deploy the ERC20 token contract
    const ERC20Token = await ethers.getContractFactory("ERC20Token");
    const token = await ERC20Token.deploy();

    // Mint some tokens for testing
   // console.log(admin.address);
    await token.mint(admin.address, 100000000000); // 100000 tokens with 6 decimals
    await token.mint(buyer.address, 100000000000); // 100000 tokens with 6 decimals
    await token.mint(seller.address, 100000000000); // 100000 tokens
   //console.log("ERC20 Token deployed at:", token.target
    

    

    // Deploy the Hiestiya contract
   
    const Hiestiya = await ethers.getContractFactory("Hiestiya");
    
    const hiestiya = await Hiestiya.deploy();
    
    // Add the token as a supported token
    await hiestiya.connect(owner).addSupportedToken(token.target);
    //console.log("ascsadc")

    //console.log("Hiestiya Contract deployed at:", hiestiya.target);

    return { hiestiya, token, owner, admin, buyer, seller, otherAccount };
  }

  describe("Deployment", function () {
    it("Should deploy the contracts and set the correct owner", async function () {
      const { hiestiya, owner } = await deployContractsFixture();

      expect(await hiestiya.owner()).to.equal(owner.address);
    });

    it("Should have no projects initially", async function () {
      const { hiestiya } = await deployContractsFixture();
      expect(await hiestiya.nextProjectId()).to.equal(0);
    });
  });

  describe("Creating a Project", function () {

    it("Should revert if total credits are zero", async function () {
      const { hiestiya, admin } = await deployContractsFixture();
      await expect(hiestiya.connect(admin).createProject("Test Project", 0, 1000))
        .to.be.revertedWith("Total credits must be greater than zero");
    });

    it("Should revert if credit price is zero", async function () {
      const { hiestiya, admin } = await deployContractsFixture();
      await expect(hiestiya.connect(admin).createProject("Test Project", 100, 0))
        .to.be.revertedWith("Credit price must be greater than zero");
    });
  });

  describe("Buying Credits", function () {
    it("Should allow a user to buy credits from a project", async function () {
      const { hiestiya, token, admin, buyer } = await deployContractsFixture();

      // Create a project first
      await hiestiya.connect(admin).createProject("Test Project", 100, 1000);

      // Approve token transfer
      await token.connect(buyer).approve(hiestiya.target, 1000000000);

      // Buy credits
      await expect(hiestiya.connect(buyer).buyCredits(1, 10, token.target))
        .to.emit(hiestiya, "CreditsBought")
        .withArgs(1, buyer.address, 10);

      const project = await hiestiya.projects(1);
      expect(project.soldCredits).to.equal(10);
      expect(project.availableCredits).to.equal(90);
    });

    it("Should revert if project does not exist", async function () {
      const { hiestiya, token, buyer } = await deployContractsFixture();
      await expect(hiestiya.connect(buyer).buyCredits(1, 10, token.target))
        .to.be.revertedWith("Project does not exist");
    });

    it("Should revert if buying more credits than available", async function () {
      const { hiestiya, token, admin, buyer } = await deployContractsFixture();

      await hiestiya.connect(admin).createProject("Test Project", 100, 1000);
      await token.connect(buyer).approve(hiestiya.target, 1000000000);

      await expect(hiestiya.connect(buyer).buyCredits(1, 110, token.target))
        .to.be.revertedWith("Invalid credit amount");
    });

    it("Should revert if token is not supported", async function () {
      const { hiestiya, admin, buyer } = await deployContractsFixture();
      const randomTokenAddress = ethers.Wallet.createRandom().address;

      await hiestiya.connect(admin).createProject("Test Project", 100, 1000);

      await expect(hiestiya.connect(buyer).buyCredits(1, 10, randomTokenAddress))
        .to.be.revertedWith("token not supported");
    });
  });

  describe("Marketplace Listings", function () {
    it("Should allow a user to list credits for sale", async function () {
      const { hiestiya, token, admin, buyer } = await deployContractsFixture();

      await hiestiya.connect(admin).createProject("Test Project", 100, 1000);
      await token.connect(buyer).approve(hiestiya.target, 10000);
      await hiestiya.connect(buyer).buyCredits(1, 10, token.target);

      await expect(hiestiya.connect(buyer).listCreditsForSale(1, 5, 2000))
        .to.emit(hiestiya, "CreditsListed")
        .withArgs(1, 1, buyer.address, 5, 2000);
    });

    it("Should revert if trying to list more credits than owned", async function () {
      const { hiestiya, token, admin, buyer } = await deployContractsFixture();

      await hiestiya.connect(admin).createProject("Test Project", 100, 1000);
      await token.connect(buyer).approve(hiestiya.target, 1000000000);
      await hiestiya.connect(buyer).buyCredits(1, 10, token.target);

      await expect(hiestiya.connect(buyer).listCreditsForSale(1, 15, 2000))
        .to.be.revertedWith("Not enough credits to list");
    });

    it("Should allow a user to buy credits from a listing", async function () {
      const { hiestiya, token, admin, buyer, seller } = await deployContractsFixture();

      await hiestiya.connect(admin).createProject("Test Project", 100, 100);
      await token.connect(seller).approve(hiestiya.target, 1000);
      await hiestiya.connect(seller).buyCredits(1, 10, token.target);
      await hiestiya.connect(seller).listCreditsForSale(1, 5, 2000);

      await token.connect(buyer).approve(hiestiya.target, 10000);
      await expect(hiestiya.connect(buyer).buyCreditsFromListing(1, 5, token.target))
        .to.emit(hiestiya, "CreditsPurchasedFromListing")
        .withArgs(1, buyer.address, 5, 2000);
    });

    it("Should revert if the listing is not active", async function () {
      const { hiestiya, token, admin, buyer, seller } = await deployContractsFixture();

      await hiestiya.connect(admin).createProject("Test Project", 100, 1000);
      await token.connect(seller).approve(hiestiya.target, 1000000000);
      await hiestiya.connect(seller).buyCredits(1, 10, token.target);
      await hiestiya.connect(seller).listCreditsForSale(1, 5, 2000);
      await hiestiya.connect(seller).cancelListing(1);

      await expect(hiestiya.connect(buyer).buyCreditsFromListing(1, 5, token.target))
        .to.be.revertedWith("Listing is not active");
    });
  });

  describe("Canceling a Listing", function () {
    it("Should allow the seller to cancel a listing", async function () {
      const { hiestiya, token, admin, buyer } = await deployContractsFixture();

      await hiestiya.connect(admin).createProject("Test Project", 100, 1000);
      await token.connect(buyer).approve(hiestiya.target, 1000000000);
      await hiestiya.connect(buyer).buyCredits(1, 10, token.target);
      await hiestiya.connect(buyer).listCreditsForSale(1, 5, 2000);

      await expect(hiestiya.connect(buyer).cancelListing(1))
        .to.emit(hiestiya, "ListingCancelled")
        .withArgs(1, buyer.address, 5);
    });

    it("Should revert if a non-seller tries to cancel a listing", async function () {
      const { hiestiya, token, admin, buyer, otherAccount } = await deployContractsFixture();

      await hiestiya.connect(admin).createProject("Test Project", 100, 1000);
      await token.connect(buyer).approve(hiestiya.target, 1000000000);
      await hiestiya.connect(buyer).buyCredits(1, 10, token.target);
      await hiestiya.connect(buyer).listCreditsForSale(1, 5, 2000);

      await expect(hiestiya.connect(otherAccount).cancelListing(1))
        .to.be.revertedWith("Only the seller can cancel the listing");
    });
  });
});