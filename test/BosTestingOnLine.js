const { ethers } = require("hardhat");
const { expect } = require("chai");
const hardhat = require("hardhat");


describe("Bos Testing", function () {

    beforeEach(async function () {
        let signers = await ethers.getSigners();
        this.deployer = signers[0];
        this.user1 = signers[1];
        this.user2 = signers[2];
        this.user3 = signers[3];
        this.user4 = signers[4];

        this.Bos = await ethers.getContractAt("BosToken","0x0146E5bdA23e8faa6c5F5D4af347d023360b2be0");
        this.USDT = await ethers.getContractAt("USDT","0x8C5089C639A9628941c5310A4F6A9eAA86EF3B4b");
        this.Cusd = await ethers.getContractAt("CusdToken","0x9A43465D4a7dE5939806d8739f5479265DD98233");
        this.Exchange = await ethers.getContractAt("Exchange","0xb0164D6B8D53A29F3c0566100090f47fEf06397B");
        // this.MintPool = await ethers.getContract("MintPool");
        // this.BosNft = await ethers.getContract("BosNft");
        this.router = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1";
        this.funder = deployer.address;
    });


    it("deposit", async function () {
        await this.USDT.mint(this.user1.address, ethers.utils.parseEther("10000000000"));
        await this.USDT.mint(this.user2.address, ethers.utils.parseEther("10000000000"));
        await this.USDT.mint(this.user3.address, ethers.utils.parseEther("10000000000"));
        await this.USDT.mint(this.user4.address, ethers.utils.parseEther("10000000000"));


        await this.USDT.connect(this.user1).approve(this.Exchange.address, ethers.constants.Maxuint256);
        await this.USDT.connect(this.user2).approve(this.Exchange.address, ethers.constants.Maxuint256);
        await this.USDT.connect(this.user3).approve(this.Exchange.address, ethers.constants.Maxuint256);
        await this.USDT.connect(this.user4).approve(this.Exchange.address, ethers.constants.Maxuint256);

        await this.Exchange.connect(this.user1).exchangeCUSD(ethers.utils.parseEther("10000"));

        console.log("user1 balance", (await this.CUSD.balanceOf(this.user1.address)).toString());a


    });

})
