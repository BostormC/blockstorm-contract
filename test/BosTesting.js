const { ethers } = require("hardhat");
const { expect } = require("chai");
const hardhat = require("hardhat");


describe("Bos Testing", function () {
    let addr1, addr2,addr3, addr4, addr5, addr6, addr7, addr8, addr9, addr10,addr11,addr12,addr13,addr14,addr15,addr16,addr17,addr18,addr19,addr20,addr21,addr22,addr23,addr24,addr25,addr26,addr27,addr28,addr29;


    let usdt;
    let cusdt;
    let bosToken;
    let bosNft;
    let market;
    let mintPool;
    let router = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1";
    let funder;


    beforeEach(async function () {
        [deployer,addr1,addr2,addr3,addr4,addr5,addr6,addr7,addr8,addr9,addr10,addr11,addr12,addr13,addr14,addr15,addr16,addr17,addr18,addr19,addr20] = await ethers.getSigners();
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
        exchange = await _exchange.deploy(usdt.address,cusdt.address,deployer.address,deployer.address);
        await exchange.deployed();
        console.log("Exchange address:", exchange.address);

        let _mintPool = await ethers.getContractFactory("MintPoolLT");
        mintPool = await _mintPool.deploy();
        await mintPool.deployed();
        console.log("MintPool address:", mintPool.address);
    });

    it('Bos contract init', async function () {
        await cusdt.initialize(deployer.address);
        console.log("cusdt initialize done");
        await bosToken.initialize(router,cusdt.address,1000000000,funder,funder,deployer.address);
        console.log("bosToken initialize done");
        await bosNft.initialize(deployer.address,bosToken.address,deployer.address);
        console.log("bosNft initialize done");
        await mintPool.initialize(router,cusdt.address,bosToken.address,bosNft.address,funder,funder,deployer.address);
        console.log("mintPool initialize done");
    });


    it('token mint', async function () {
        let amount = "1000000000000000000000000000000000";

        await cusdt.mint(deployer.address,amount);
        await cusdt.approve(mintPool.address,amount)

        await cusdt.mint(addr1.address,amount);
        await cusdt.connect(addr1).approve(mintPool.address,amount);

        await usdt.mint(deployer.address,amount);
        await usdt.approve(mintPool.address,amount)
    
        await usdt.mint(addr1.address,amount);
        await usdt.connect(addr1).approve(mintPool.address,amount)

        console.log(await bosToken.balanceOf(deployer.address))

        console.log("mint init ok");
    
    });

    it('pool testing', async function () {
        let amount = "4000000000000000000000";

        await mintPool.open();

        console.log("open ok")

        await mintPool.connect(addr1).deposit(amount,"0",deployer.address);
        await mintPool.connect(addr2).deposit(amount,"0",addr1.address);
        await mintPool.connect(addr3).deposit(amount,"0",addr1.address);
        await mintPool.connect(addr4).deposit(amount,"0",addr2.address);
        await mintPool.connect(addr5).deposit(amount,"0",addr2.address);
        await mintPool.connect(addr6).deposit(amount,"0",addr3.address);
        await mintPool.connect(addr7).deposit(amount,"0",addr3.address);
        await mintPool.connect(addr8).deposit(amount,"0",addr4.address);
        await mintPool.connect(addr9).deposit(amount,"0",addr4.address);
        await mintPool.connect(addr10).deposit(amount,"0",addr5.address);
        await mintPool.connect(addr11).deposit(amount,"0",addr5.address);
        await mintPool.connect(addr12).deposit(amount,"0",addr6.address);
        await mintPool.connect(addr13).deposit(amount,"0",addr6.address);
        await mintPool.connect(addr14).deposit(amount,"0",addr7.address);
        await mintPool.connect(addr15).deposit(amount,"0",addr7.address);

        console.log(await mintPool.userLevel(addr1.address));
        console.log(await mintPool.userLevel(addr2.address));
        console.log(await mintPool.userLevel(addr3.address));
        console.log(await mintPool.userLevel(addr4.address));
        console.log(await mintPool.userLevel(addr5.address));
        console.log(await mintPool.userLevel(addr6.address));
        console.log(await mintPool.userLevel(addr7.address));
        console.log(await mintPool.userLevel(addr8.address));
        console.log(await mintPool.userLevel(addr9.address));
        console.log(await mintPool.userLevel(addr10.address));
        console.log(await mintPool.userLevel(addr11.address));
        console.log(await mintPool.userLevel(addr12.address));
        console.log(await mintPool.userLevel(addr13.address));
        console.log(await mintPool.userLevel(addr14.address));
        console.log(await mintPool.userLevel(addr15.address));

        // await mintPool.connect(addr1).deposit(amount,"0",deployer.address);
        //
        // console.log(await mintPool.userLevel(addr1.address));
        // console.log(await mintPool.userLevel(addr2.address));
        // console.log(await mintPool.userLevel(addr3.address));
        // console.log(await mintPool.userLevel(addr4.address));
        // console.log(await mintPool.userLevel(addr5.address));

    });
})
