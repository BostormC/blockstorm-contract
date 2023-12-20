const { ethers } = require("hardhat");
const { expect } = require("chai");
const hardhat = require("hardhat");


describe("Bos Testing", function () {
    let addr1, addr2;


    let usdt;
    let cusdt;
    let bosToken;
    let bosNft;
    let market;
    let mintPool;
    let router = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1";
    let funder;


    beforeEach(async function () {
        [deployer,addr1,addr2] = await ethers.getSigners();
        funder = deployer.address;
    });

    it("bos contract deploy init", async function () {
        console.log("deployer address:",deployer.address)

        let _usdt = await ethers.getContractFactory("USDT");
        usdt = await _usdt.deploy("USDT","USDT");
        await usdt.deployed();
        console.log("USDT address:", usdt.address);

        let _cusdt = await ethers.getContractFactory("CusdToken");
        cusdt = await _cusdt.deploy();
        await cusdt.deployed();
        console.log("CusdToken address:", cusdt.address);


        let _bosToken = await ethers.getContractFactory("BosToken");
        bosToken = await _bosToken.deploy();
        await bosToken.deployed();
        console.log("BosToken address:", bosToken.address);


        let _bosNft = await ethers.getContractFactory("BOSNFT");
        bosNft = await _bosNft.deploy();
        await bosNft.deployed();
        console.log("BOSNFT address:", bosNft.address);

        let _exchange = await ethers.getContractFactory("Exchange");
        exchange = await _exchange.deploy(usdt.address,cusdt.address,deployer.address);
        await exchange.deployed();
        console.log("Exchange address:", exchange.address);

        let _mintPool = await ethers.getContractFactory("MintPool");
        mintPool = await _mintPool.deploy();
        await mintPool.deployed();
        console.log("MintPool address:", mintPool.address);
    });

    it('Bos contract init', async function () {
        await cusdt.initialize(deployer.address);
        console.log("cusdt initialize done");
        // address _router, 
        // address _usdtAddress,
        // uint256 _supply,
        // address _recevie, 
        // address _fund,
        // address _owner)
        await bosToken.initialize(router,cusdt.address,1000000000,funder,funder,deployer.address);
        console.log("bosToken initialize done");
        await bosNft.initialize(deployer.address,bosToken.address,deployer.address);
        console.log("bosNft initialize done");
        await mintPool.initialize(router,cusdt.address,bosToken.address,bosNft.address,funder,funder,deployer.address);
        console.log("mintPool initialize done");
    });


    it('token mint', async function () {
        let amount = "1000000000000000000000000000000000";

        let _router = await ethers.getContractFactory("Router");
        let router = await _router.deploy();
        await router.deployed();
        

        await cusdt.mint(deployer.address,amount);
        await cusdt.approve(mintPool.address,amount)

        await cusdt.mint(addr1.address,amount);
        await cusdt.connect(addr1).approve(mintPool.address,amount);

        await usdt.mint(deployer.address,amount);
        await usdt.approve(mintPool.address,amount)
    
        await usdt.mint(addr1.address,amount);
        await usdt.connect(addr1).approve(mintPool.address,amount)
    });

    it('pool testing', async function () {
        
        
    });
})
