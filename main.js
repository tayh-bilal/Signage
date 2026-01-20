const { app, BrowserWindow } = require('electron');
const path = require('path');
const { autoUpdater } = require("electron-updater"); // ✅ Added this

// Configure the updater
autoUpdater.autoDownload = true;
autoUpdater.on('update-downloaded', () => {
  // This forces the app to restart and install the update immediately
  autoUpdater.quitAndInstall(); 
});

function createWindow() {
  const win = new BrowserWindow({
    fullscreen: true,
    autoHideMenuBar: true,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
      autoplayPolicy: 'no-user-gesture-required',
      additionalArguments: [`--userDataPath=${app.getPath('userData')}`]
    }
  });

  win.loadFile(path.join(__dirname, 'player.html'));

  // ✅ Check for updates as soon as the app starts
  win.once('ready-to-show', () => {
    autoUpdater.checkForUpdatesAndNotify();
  });
}

app.whenReady().then(createWindow);

// ✅ Check for updates every 60 minutes
setInterval(() => {
  autoUpdater.checkForUpdatesAndNotify();
}, 3600000);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});