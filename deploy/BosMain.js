module.exports = async function ({ethers, deployments}) {
    const {deploy} = deployments
    const accounts = await ethers.getSigners()
    const deployer = accounts[0];

    console.log("deployer address:", deployer.address);

    let funder = "0xD61ab6be14ee148505ab85678D8b68f072D435a8";
    let router = "0x10ED43C718714eb63d5aA57B78B54704E256024E";
    let usdt = "0x55d398326f99059ff775485246999027b3197955";
    let bosReceive = "0xb00F40Fa13112DBE4592EcF944e900Bb953599fF";
    let cusdReceive = "0x4901a332B51F67F0f611fE0BddE08f7218302200";
    let defInv = "0xd87B5998860B12fbaC974264faa296c187b41DE3";


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
        await bos.initialize(router,cusdt.address,21000000,deployer.address,funder,deployer.address);
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
    // await mintPool.bindInvitor("0x3226750136a5d53c93dbfd5d652042f14b82b1f4",defInv);
    // console.log("MintPool bindInvitor:ok");


    //  await run('verify:verify', {
    //     address:"0xA16c96022d99a7fa412BAac81c5B541C2fb4102D",
    //     constructorArguments: []
    // });


    // await cusdt.approve(batchTransfer.address,"1000000000000000000000000000000000000000000000000000000000000000000000000000");
    // await bos.approve(batchTransfer.address,"100000000000000000000000000000000000000000000000000000000000000000000000000000");

    // let lp = ethers.getContractAt("IERC20", "0xbb9Db2DdFE61a3dc17cCeF1825701bE4767020E2");
    // await lp.approve(batchTransfer.address,"10000000000000000000000000000000000000000000000000000000000000000000000000000000");

    // await cusdt.updateWhitelistEnabled(true);
    // await cusdt.updateWhitelist("0x456886b7DD080d22236caE02bEBF292413fb37C4",true)
    // await cusdt.updateWhitelist(deployer.address,true);
    //await cusdt.updateWhitelist(mintPool.address,true);
    // await cusdt.updateWhitelist(cusdReceive,true);

    // await mintPool.setInProject(funder,true);

    console.log(await mintPool.referralAmount("0xa9040ae8C5b4D567Ebcb3314A51626DF807e9338"));

}

module.exports.tags = ['BosMain']