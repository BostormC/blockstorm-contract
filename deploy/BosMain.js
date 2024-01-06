module.exports = async function ({ethers, deployments}) {
    const {deploy} = deployments
    const accounts = await ethers.getSigners()
    const deployer = accounts[0];

    console.log("deployer address:", deployer.address);

    let funder = "0x49843b49d0D7953C650a9a327320FfA14384F14B";
    let router = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
    let usdt = "0x55d398326f99059ff775485246999027b3197955";
    let bosReceive = "0xd741C0CA20f73CB8c214bC5c192d5f2F213c5fDE";
    let defInv = "0x1845c9bE7586F677a7FD81263e7d5F935a922DDc";


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
        let cusdtinit = await cusdt.initialize(bosReceive,deployer.address);
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
        await bos.initialize(router,cusdt.address,21000000,bosReceive,funder,deployer.address);
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
        let bosinit = await bosNft.initialize(funder,bos.address,deployer.address);
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



    if ((await mintPool._sellNFTRate()) == 0){
        let poolInit = await mintPool.initialize(router,cusdt.address,bos.address,bosNft.address,defInv,funder,deployer.address);
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
    //
    //
    // let setMinPool = await bos.setMinPool(mintPool.address);
    // await setMinPool.wait();
    // console.log("bos setMinPool:", setMinPool.hash);
    //
    // await mintPool.open();
    // console.log("MintPool open:", mintPool.hash);
    // await mintPool.setNFTAddress(bosNft.address);
    // console.log("MintPool setNFTAddress:", mintPool.hash);
    //
    // await bos.setPauseGiveReward(false);
    //
    // console.log("bos setPauseGiveReward:ok");
    //
    // let watb = await mintPool.setInProject(bos.address,true);
    // watb.wait();
    //
    // console.log("MintPool setInProject:ok");
    //
    // await bosNft.setMintpool(mintPool.address);
    //
    // console.log("BOSNFT setMintpool:ok");
    //
    // await bosNft.setRewardAdmin(mintPool.address,true);
    // console.log("BOSNFT setRewardAdmin:ok");
    //
    //
    // await cusdt.approve(batchTransfer.address,"1000000000000000000000000000000000000000000000000000000000000000000000000000");
    // await bos.approve(batchTransfer.address,"100000000000000000000000000000000000000000000000000000000000000000000000000000");
    //
    // // let lp = ethers.getContractAt("IERC20", "0xbb9Db2DdFE61a3dc17cCeF1825701bE4767020E2");
    // // await lp.approve(batchTransfer.address,"10000000000000000000000000000000000000000000000000000000000000000000000000000000");
    //
    // let aw = await cusdt.updateWhitelistEnabled(true);
    // await aw.wait();
    //
    // await cusdt.updateWhitelist(batchTransfer.address,true)
    // await cusdt.updateWhitelist(deployer.address,true);
    // await cusdt.updateWhitelist(mintPool.address,true);
    // await cusdt.updateWhitelist(bosReceive,true);
    // await mintPool.setInProject(funder,true);



    // await run('verify:verify', {
    //     address: "0xE028f99b0b6fF7D866b4D0F30DCA1240A47c600C",
    //     constructorArguments: []
    // });

    // await run('verify:verify', {
    //     address: "0x237ab9fA639eD24a3F5e45C3abBbC3DC50331c9c",
    //     constructorArguments: []
    // });

    // await run('verify:verify', {
    //     address: "0xe30618886F4bd165FaadcBfe479Ab569858D617E",
    //     constructorArguments: []
    // });

    // await run('verify:verify', {
    //     address: "0xa5f894Bc32268E25e7b1c42BA32bf2009c236b1e",
    //     constructorArguments: []
    // });
    // await run('verify:verify', {
    //     address: "0xE175670658c405A61F1B2fd9319043F70eCb0EFD",
    //     constructorArguments: [usdt,cusdt.address,funder,deployer.address]
    // });



    console.log(await mintPool.userLevel("0x1845c9bE7586F677a7FD81263e7d5F935a922DDc"));

}

module.exports.tags = ['BosMain']