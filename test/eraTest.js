const { expect, assert } = require("chai");
const { ethers, network } = require("hardhat");

describe("SeniorPool", function () {
  let era;

  beforeEach(async () => {
    accounts = await ethers.getSigners();
    // deploy DygnifyConfig.sol
    const ERA = await ethers.getContractFactory("ERA");
    era = await ERA.deploy();
    await era.deployed();
  });

  describe("list", function () {
    describe("Positive cases", function () {
      it("", async function () {
        console.log("HI");
      });
    });

    describe("Negative cases", function () {
      it("", async function () {
        console.log("HI");
      });
    });
  });
});
