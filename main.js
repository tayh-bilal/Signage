const { app, BrowserWindow, powerSaveBlocker, ipcMain } = require('electron');
const path = require('path');

let autoUpdater;

// 🛡️ Setup Updater (Passive Mode)
try {
    autoUpdater = require('electron-updater').autoUpdater;
    autoUpdater.autoDownload = true;

    autoUpdater.on('update-downloaded', () => {
        console.log('Update downloaded. Rebooting...');
        autoUpdater.quitAndInstall();
    });

    autoUpdater.on('error', (err) => {
        console.log('Update Error: ' + err);
    });
} catch (e) {
    console.log('electron-updater not available');
}

function createWindow() {
    const win = new BrowserWindow({
        fullscreen: true,
        autoHideMenuBar: true,
        backgroundColor: '#000000',
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false,
            autoplayPolicy: 'no-user-gesture-required',
            // Pass the current version to the HTML file
            additionalArguments: [
                `--userDataPath=${app.getPath('userData')}`,
                `--appVersion=${app.getVersion()}` 
            ]
        }
    });

    win.loadFile(path.join(__dirname, 'player.html'));
}

// 👂 Listen for the trigger from the HTML file
ipcMain.on('trigger-update', () => {
    if (autoUpdater) {
        console.log("Renderer requested update check...");
        autoUpdater.checkForUpdatesAndNotify();
    }
});

app.whenReady().then(() => {
    powerSaveBlocker.start('prevent-display-sleep');
    createWindow();
});

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
});