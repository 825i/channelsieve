let enabled = true;

// Must stay in sync with host_permissions / content_scripts.matches in the manifests.
const YOUTUBE_ORIGINS = ['https://www.youtube.com/*', 'https://m.youtube.com/*'];

document.addEventListener('DOMContentLoaded', () => {

  function detectColorScheme() {

    chrome.storage.local.get("storageData", (result) => {
      let uiTheme = "light";
      let storageTheme = result.storageData?.uiTheme;

      if(storageTheme){
        uiTheme = storageTheme;
      } else if(!window.matchMedia) {
        uiTheme = "light";
      } else if(window.matchMedia("(prefers-color-scheme: dark)").matches) {
        uiTheme = "dark";
      }

      document.documentElement.setAttribute("data-theme", uiTheme);
    });
  }

  detectColorScheme();
  

  const checkbox = document.getElementById("toggle-extension");
  const statusText = document.getElementById("status-text");

  chrome.storage.onChanged.addListener((changes) => {
    if (Object.hasOwn(changes, 'enabled')) {
      enabled = !!changes.enabled.newValue;
      checkbox.checked = enabled;
      statusText.textContent = enabled ? "On" : "Off";
    }
  });

  // Restore the switch state from storage
  chrome.storage.local.get(["enabled", "storageData"], (result) => {
    if (result.storageData && result.storageData.uiPass) {
      if (chrome.runtime.openOptionsPage) {
        chrome.runtime.openOptionsPage();
        window.close();
      }
    }

    if (result.enabled === undefined) {
      result.enabled = true;
    }
    checkbox.checked = !!result.enabled;
    statusText.textContent = !!result.enabled ? "On" : "Off";
  });

  // Listen for changes to the switch
  checkbox.addEventListener("change", (event) => {
    if (event.target instanceof HTMLInputElement) {
      console.log({enabled: !!event.target.checked})
        chrome.storage.local.set({enabled: !!event.target.checked});
        chrome.tabs.reload(); // Reload page to apply the new state
    }
  });

  // On Firefox MV3 the YouTube host permission is optional and is not always granted at
  // install time. Until it is, the content scripts never inject and the extension does
  // nothing at all with no visible sign of why, so surface it and offer a one-click fix.
  const permissionWarning = document.getElementById("permission-warning");
  const grantButton = document.getElementById("grant-button");

  function refreshPermissionState() {
    if (!chrome.permissions || !chrome.permissions.contains) return;
    chrome.permissions.contains({ origins: YOUTUBE_ORIGINS }, (granted) => {
      permissionWarning.hidden = !!granted;
    });
  }

  refreshPermissionState();

  // permissions.request() needs a user gesture, so it has to run from the click handler
  grantButton.addEventListener("click", () => {
    chrome.permissions.request({ origins: YOUTUBE_ORIGINS }, (granted) => {
      if (!granted) return;
      permissionWarning.hidden = true;
      chrome.tabs.reload(); // content scripts only inject at document_start
      window.close();
    });
  });

  // Open options page
  document.getElementById("options-button").addEventListener("click", () => {
    if (chrome.runtime.openOptionsPage) {
      chrome.runtime.openOptionsPage();
      window.close();
    }
  });
});