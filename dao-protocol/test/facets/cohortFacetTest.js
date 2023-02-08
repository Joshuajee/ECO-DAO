/* global describe it before ethers */

const { deployDiamond } = require("../../scripts/deploy.js");

const { assert } = require("chai");

describe("CohortFacetTest", async function () {
  let diamondAddress;
  let cohortFactoryFacet;
  let cohort;
  let cohortAddress;
  let usdc;
  let ekoNft;
  let ekoUsdc;
  let studentAddress = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";

  before(async function () {
    diamondAddress = await deployDiamond();
    cohortFactoryFacet = await ethers.getContractAt(
      "CohortFactoryFacet",
      diamondAddress
    );
    const USDC = await ethers.getContractFactory("USDC");
    usdc = await USDC.deploy();
    await usdc.deployed();
    console.log("USDC deployed:", usdc.address);

    const EkoNFT = await ethers.getContractFactory("EkoNFT");
    ekoNft = await EkoNFT.deploy();
    await ekoNft.deployed();
    console.log("EkoNFT deployed:", ekoNft.address);
  });

  it("should create new cohort", async () => {
    const currentDate = new Date();
    const currentTimestamp = currentDate.getTime();
    const startDate = currentTimestamp + 30;
    const endDate = currentTimestamp + 60;
    await cohortFactoryFacet.newCohort(1, startDate, endDate, 100, 10);
    cohortAddress = await cohortFactoryFacet.cohorts(1);
    const Cohort = await ethers.getContractFactory("Cohort");
    cohort = await Cohort.attach(cohortAddress);
    const record = await cohort.cohort();
    assert.equal(record.startDate, startDate);
    assert.equal(record.endDate, endDate);
    assert.equal(record.size, 100);
    assert.equal(record.commitment, 10);
  });

  it("should enroll student in a cohort", async () => {
    await usdc.mint(studentAddress, 10);
    await usdc.approve(cohortAddress, 10);

    await cohort.init(usdc.address, ekoNft.address);

    const ekoUSDCAddress = await cohort.ekoUSDCAddress();
    const EkoUSDC = await ethers.getContractFactory("EkoUSDC");
    ekoUsdc = await EkoUSDC.attach(ekoUSDCAddress);

    const studentUsdcBalanceBeforeEnroll = await usdc.balanceOf(studentAddress);
    assert.equal(studentUsdcBalanceBeforeEnroll, 10);
    const studentEkoUsdcBalanceBeforeEnroll = await ekoUsdc.balanceOf(
      studentAddress
    );
    assert.equal(studentEkoUsdcBalanceBeforeEnroll, 0);
    const cohortUsdcBalanceBeforeEnroll = await usdc.balanceOf(cohortAddress);
    assert.equal(cohortUsdcBalanceBeforeEnroll, 0);

    await cohort.enroll(10);

    const studentUsdcBalanceAfterEnroll = await usdc.balanceOf(studentAddress);
    assert.equal(studentUsdcBalanceAfterEnroll, 0);
    const studentEkoUsdcBalanceAfterEnroll = await ekoUsdc.balanceOf(
      studentAddress
    );
    assert.equal(studentEkoUsdcBalanceAfterEnroll, 10);
    const cohortUsdcBalanceAfterEnroll = await usdc.balanceOf(cohortAddress);
    assert.equal(cohortUsdcBalanceAfterEnroll, 10);
  });

  it("should test cohort", async () => {
    const tokenId = await ekoNft.safeMint(studentAddress);
    await ekoUsdc.approve(cohortAddress, 10);

    await cohort.refund(10, tokenId.value);

    const studentUsdcBalanceAfterRefund = await usdc.balanceOf(studentAddress);
    assert.equal(studentUsdcBalanceAfterRefund, 10);
    const studentEkoUsdcBalanceAfterRefund = await ekoUsdc.balanceOf(
      studentAddress
    );
    assert.equal(studentEkoUsdcBalanceAfterRefund, 0);
    const cohortUsdcBalanceAfterRefund = await usdc.balanceOf(cohortAddress);
    assert.equal(cohortUsdcBalanceAfterRefund, 0);
  });
});
