module.exports = async function ({ethers, deployments}) {
    const {deploy} = deployments
    const accounts = await ethers.getSigners()
    const deployer = accounts[0];

    console.log("deployer address:", deployer.address);

    let funder = deployer.address;
    let router = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1";
    // let usdt = "0x55d398326f99059ff775485246999027b3197955";

    await deploy('USDT', {
        from: deployer.address,
        args: ["usdt","usdt"],
        log: true,
        contract: 'USDT',
    })

    let usdtToken = await ethers.getContract('USDT');
    let usdt = usdtToken.address;

    // await run('verify:verify', {
    //     address: usdtToken.address,
    //     constructorArguments: ["usdt","usdt"]
    // });

    // await usdtToken.mint("0x20aF189a924E816367f076d7596A3D95ef6db0c3","1000000000000000000000000")


    await deploy('CusdToken', {
        from: deployer.address,
        args: [],
        log: true,
        contract: 'CusdToken',
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
        },
    })

    let cusdt = await ethers.getContract('CusdToken');
    if ((await cusdt.name()).toString()!= "CUSD" ){
        console.log("CUSD initialized");
        let cusdtinit = await cusdt.initialize(deployer.address);
        cusdtinit.wait();
    }
    console.log("CusdToken address:", cusdt.address);

    await deploy('BosToken', {
        from: deployer.address,
        args: [],
        log: true,
        contract: 'BosToken',
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
        },
    })

    let bos = await ethers.getContract('BosToken');
    console.log("BosToken address:", bos.address);


    if (await bos.name()!= "Block Storm"){
        let initBos = 
        await bos.initialize(router,cusdt.address,10000000,funder,funder,deployer.address);
        await initBos.wait();
        console.log("BosToken initialize:", initBos.hash);
    }


    await deploy('BOSNFT', {
        from: deployer.address,
        args: [],
        log: true,
        contract: 'BOSNFT',
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
        },
    })

    let bosNft = await ethers.getContract('BOSNFT');
    console.log("BOSNFT address:", bosNft.address);

    if (await bosNft.name()!= "BOSNFT"){
        let bosinit = await bosNft.initialize(deployer.address,bos.address,deployer.address);
        bosinit.wait();
        console.log("BOSNFT initialized");
    }

    console.log("BOSNFT name:", await bosNft.name());
    console.log("BOSNFT name:", await bosNft.tokenURI(1));



    await deploy('Exchange', {
        from: deployer.address,
        args: [usdt,cusdt.address,funder,deployer.address],
        log: true,
        contract: 'Exchange'
    })


    let exchange = await ethers.getContract('Exchange');
    console.log("Exchange address:", exchange.address);


    await deploy('MintPool', {
        from: deployer.address,
        args: [],
        log: true,
        contract: 'MintPool',
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
        },
    })

    let mintPool = await ethers.getContract('MintPool');
    console.log("MintPool address:", mintPool.address);


    await run('verify:verify', {
        address: "0xbCEac23628A90609499fc2D6892998fF47169Fa8",
        constructorArguments: []
    });


    if ((await mintPool._sellNFTRate()) == 0){
        let poolInit = await mintPool.initialize(router,cusdt.address,bos.address,bosNft.address,funder,funder,deployer.address);
        await poolInit.wait();
        console.log("MintPool initialize:", poolInit.hash);
    }



    await deploy('BatchTransfer', {
        from: deployer.address,
        args: [],
        log: true,
        contract: 'BatchTransfer',
    })

    let batchTransfer = await ethers.getContract('BatchTransfer');
    console.log("BatchTransfer address:", batchTransfer.address)





    // let amount = "100000000000000000000000000";

    // let setMinPool = await bos.setMinPool(mintPool.address);
    // await setMinPool.wait();
    // console.log("bos setMinPool:", setMinPool.hash);




    // await cusdt.approve(mintPool.address,amount)
    // console.log("approve ok");
    // await mintPool.deposit("100000000000000000000","0",funder)
    // console.log("deposit ok");

    // await mintPool.open();
    // await mintPool.setNFTAddress(bosNft.address);
    // let wat = await mintPool.deposit("100000000000000000000","0",funder)
    // wat.wait();

    // await bos.setPauseGiveReward(false);

    // let watb = await mintPool.setInProject(bos.address,true);
    // watb.wait();

    // let wat = await mintPool.deposit("100000000000000000000","0",funder)
    // wat.wait();

    // console.log(await mintPool.getPendingMintReward(funder));
    //
    // console.log(await mintPool.poolInfo());

    // await mintPool.claimLP()

    // await mintPool.setUserLevel("0x20aF189a924E816367f076d7596A3D95ef6db0c3",1);

    // await bosNft.setMintpool(mintPool.address);

    // let c = await usdtToken.approve(exchange.address,"1000000000000000000000000000000000000000000000000000000000000000000000000000");
    // c.wait();
    // await exchange.exchangeCUSD("1000000000000000000000");
    // await bosNft.setRewardAdmin(mintPool.address,true);
    // await mintPool.bindInvitor("0x3226750136a5d53c93dbfd5d652042f14b82b1f4",deployer.address);
    // console.log(await mintPool.poolInfo())

    // await cusdt.mint(deployer.address,ethers.utils.parseEther("100000000"));
    // await bos.mint(deployer.address,ethers.utils.parseEther("100000000"));

    // await cusdt.approve(batchTransfer.address,ethers.utils.parseEther("1000000000000000000"));
    // await bos.approve(batchTransfer.address,ethers.utils.parseEther("1000000000000000000"));

    // await cusd.addToBlacklist("0xc856F71cEC6Fa0FD83E675d06C8ee6327d91aca1");

    await mintPool.claim();



}

module.exports.tags = ['Bos']