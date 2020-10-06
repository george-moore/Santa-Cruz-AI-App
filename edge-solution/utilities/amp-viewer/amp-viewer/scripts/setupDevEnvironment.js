// tslint:disable:no-console
const os = require('os');
const path = require('path');
const fse = require('fs-extra');
const uuid = require('uuid');

const processArgs = require('commander')
    .option('-r, --workspace-root <workspaceRoot>', 'Workspace root folder path')
    .parse(process.argv);

const osType = os.type();
const workspaceRootFolder = processArgs.workspaceRoot || process.cwd();

function createDevConfiguration(srcFile, dstFolder, dstFile) {
    if (!fse.pathExistsSync(dstFile)) {
        console.log(`Creating configuration: ${dstFile}`);

        fse.ensureDirSync(dstFolder);

        try {
            fse.copyFileSync(srcFile, dstFile);
        }
        catch (ex) {
            console.log(ex.message);
        }
    }
}

function start() {
    console.log(`Creating workspace environment: ${workspaceRootFolder}`);
    console.log(`Platform: ${osType}`);

    let setupFailed = false;

    try {
        if (!workspaceRootFolder) {
            throw '';
        }

        let configDirDst;
        let configFileDst;

        configDirDst = path.resolve(workspaceRootFolder, `configs`);
        configFileDst = path.resolve(configDirDst, `imageConfig.json`);
        createDevConfiguration(path.resolve(workspaceRootFolder, `setup`, `imageConfig.json`), configDirDst, configFileDst);

        configDirDst = path.resolve(workspaceRootFolder, `configs`);
        configFileDst = path.resolve(configDirDst, `local.json`);
        createDevConfiguration(path.resolve(workspaceRootFolder, `setup`, `local.json`), configDirDst, configFileDst);
    } catch (e) {
        setupFailed = true;
    } finally {
        if (!setupFailed) {
            console.log(`Operation complete`);
        }
    }

    if (setupFailed) {
        console.log(`Operation failed, see errors above`);
        process.exit(-1);
    }
}

start();
// tslint:enable:no-console
