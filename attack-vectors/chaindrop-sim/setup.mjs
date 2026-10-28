// Safe Educational Simulation of ChainDrop / Shai-Hulud preinstall payload (setup.mjs)
console.log("\n========================================================");
console.log("🚨 [CHAINDROP / SHAI-HULUD SIMULATOR] preinstall hook ran!");
console.log("========================================================");

const sensitiveVars = Object.keys(process.env).filter((k) =>
  /GOOGLE|GCP|AWS|TOKEN|SECRET|KEY|GITHUB|KUBE/i.test(k)
);

console.log(`🔍 Scanned process.env -> Found ${sensitiveVars.length} matching environment keys:`);
sensitiveVars.slice(0, 8).forEach((k) => console.log(`   - ${k} = [REDACTED_IN_SIMULATION]`));
console.log("💀 If ignore-scripts=true was NOT set, an unhardened CI runner just leaked its environment!\n");
process.exit(1);
