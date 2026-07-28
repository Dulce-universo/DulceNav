// ==============================================================
// DulceNav - webview_scripts.dart
// Constantes de Javascript inyectadas en los WebViews (multiplataforma).
// ==============================================================

class WebViewScripts {
  // Shim de compatibilidad para Android
  // Mapea window.chrome.webview.postMessage a llamadas del handler de InAppWebView
  static const String androidShimScript = r'''
    (function(){
      if (!window.chrome) window.chrome = {};
      if (!window.chrome.webview) window.chrome.webview = {};
      window.chrome.webview.postMessage = function(message) {
        window.flutter_inappwebview.callHandler('webMessage', message);
      };
    })();
  ''';

  // ── Script 1: Privacidad y rendimiento ─────────────────
  static const String privacyScript = r'''
    (function(){
    "use strict";
    var _h=location.hostname||"";
    var _authDomains=[
      "accounts.google.com","google.com","googleapis.com",
      "github.com","microsoft.com","live.com","microsoftonline.com",
      "facebook.com","apple.com","twitter.com","x.com",
      "login.microsoftonline.com","appleid.apple.com"
    ];
    var _isAuth=_authDomains.some(function(d){return _h===d||_h.endsWith("."+d);});

    if(navigator.geolocation){
      try{Object.defineProperty(navigator,"geolocation",{get:function(){return undefined;},configurable:false});}catch(e){}
    }
    if(window.Notification){
      try{Object.defineProperty(window,"Notification",{get:function(){return undefined;},configurable:false});}catch(e){}
    }
    if(!_isAuth && navigator.serviceWorker){
      try{Object.defineProperty(navigator,"serviceWorker",{get:function(){return undefined;},configurable:false});}catch(e){}
    }
    document.addEventListener("DOMContentLoaded",function(){
      document.querySelectorAll("video,audio").forEach(function(el){
        el.autoplay=false;
        if(el.pause)el.pause();
      });
    },{once:true});
    var _si=window.setInterval;
    window.setInterval=function(fn,d){
      var a=Array.prototype.slice.call(arguments,2);
      return _si.apply(window,[fn,Math.max(d||0,100)].concat(a));
    };
    })();
  ''';

  // ── Script de Descargas ────────────────────────────────
  static const String downloadInterceptorScript = r'''
    (function(){
    "use strict";
    document.addEventListener("click", function(e) {
      var target = e.target;
      while (target && target.tagName !== "A") {
        target = target.parentNode;
      }
      if (target && target.href) {
        var href = target.href;
        if (href.startsWith("http://") || href.startsWith("https://")) {
          var urlNoParams = href.split("?")[0].split("#")[0];
          var parts = urlNoParams.split("/");
          var filename = parts[parts.length - 1] || "";
          var extPattern = /\.(zip|rar|7z|tar|gz|exe|msi|apk|dmg|iso|pdf|jpg|jpeg|png|gif|mp3|mp4|avi|mkv|docx|xlsx|pptx|txt|csv)$/i;
          if (extPattern.test(filename)) {
            e.preventDefault();
            try {
              window.chrome.webview.postMessage(JSON.stringify({
                type: "download",
                url: href,
                fileName: filename
              }));
            } catch (err) {}
          }
        }
      }
    }, true);
    })();
  ''';

  // ── Script de DuckDuckGo AdBlocker ─────────────────────
  static const String ddgAdBlockScript = r'''
    (function(){
    "use strict";
    if (window.location.hostname.indexOf("duckduckgo.com") === -1) return;

    function removeDDGAds() {
      var adSelectors = [
        ".result--ad",
        "[data-testid=\"ad\"]",
        ".badge--ad",
        ".is-sponsored",
        "#ads",
        ".results--ads"
      ];
      adSelectors.forEach(function(sel) {
        var els = document.querySelectorAll(sel);
        els.forEach(function(el) {
          el.remove();
        });
      });
    }

    removeDDGAds();

    var observer = new MutationObserver(function(mutations) {
      removeDDGAds();
    });
    observer.observe(document.documentElement, {
      childList: true,
      subtree: true
    });
    })();
  ''';

  // ── Script de Deteccion de Contenido Multimedia ────────
  static const String mediaDetectionScript = r'''
    (function(){
    "use strict";
    var activePlayers = new Set();

    function updateMediaState() {
      var isPlaying = activePlayers.size > 0;
      try {
        window.chrome.webview.postMessage(JSON.stringify({
          type: "mediaState",
          playing: isPlaying
        }));
      } catch(e) {}
    }

    function registerMediaElement(el) {
      if (el.dataset.dulceTracked) return;
      el.dataset.dulceTracked = "true";

      el.addEventListener("play", function() {
        activePlayers.add(el);
        updateMediaState();
      });

      el.addEventListener("pause", function() {
        activePlayers.delete(el);
        updateMediaState();
      });

      el.addEventListener("ended", function() {
        activePlayers.delete(el);
        updateMediaState();
      });
      
      if (!el.paused) {
        activePlayers.add(el);
        updateMediaState();
      }
    }

    function scanMedia() {
      document.querySelectorAll("video, audio").forEach(registerMediaElement);
    }

    scanMedia();
    setInterval(scanMedia, 3000);

    var observer = new MutationObserver(function(mutations) {
      scanMedia();
    });
    observer.observe(document.documentElement, {
      childList: true,
      subtree: true
    });
    })();
  ''';

  // ── Script de Deteccion de Contraseñas ──────────────────
  static const String passwordDetectionScript = r'''
    (function(){
    "use strict";

    if (window.dulceIncognitoMode) return;

    function handleFormSubmit(form) {
      var passwordInput = form.querySelector("input[type='password']");
      if (!passwordInput || !passwordInput.value) return;

      var usernameInput = form.querySelector("input[type='text'], input[type='email'], input[name*='user'], input[name*='login'], input[name*='email']");
      var username = usernameInput ? usernameInput.value : "";
      var password = passwordInput.value;
      var domain = window.location.hostname;

      if (username && password) {
        try {
          window.chrome.webview.postMessage(JSON.stringify({
            type: "loginDetected",
            domain: domain,
            username: username,
            password: password
          }));
        } catch(e) {}
      }
    }

    document.addEventListener("submit", function(e) {
      if (e.target && e.target.tagName === "FORM") {
        handleFormSubmit(e.target);
      }
    }, true);

    document.addEventListener("click", function(e) {
      var target = e.target;
      while (target && target.tagName !== "BUTTON" && target.tagName !== "INPUT") {
        target = target.parentNode;
      }
      if (target && (target.type === "submit" || (target.innerText && (target.innerText.toLowerCase().indexOf("iniciar") !== -1 || target.innerText.toLowerCase().indexOf("login") !== -1 || target.innerText.toLowerCase().indexOf("ingresar") !== -1)))) {
        var form = target.form;
        if (form) {
          handleFormSubmit(form);
        } else {
          var passwords = document.querySelectorAll("input[type='password']");
          passwords.forEach(function(pwd) {
            if (pwd.value) {
              var formContainer = pwd.closest("form") || document;
              var usernameInput = formContainer.querySelector("input[type='text'], input[type='email'], input[name*='user'], input[name*='login']");
              var username = usernameInput ? usernameInput.value : "";
              var domain = window.location.hostname;
              try {
                window.chrome.webview.postMessage(JSON.stringify({
                  type: "loginDetected",
                  domain: domain,
                  username: username,
                  password: pwd.value
                }));
              } catch(e) {}
            }
          });
        }
      }
    }, true);
    })();
  ''';

  // ── Script de intercepcion de click derecho (Context Menu) ──
  static const String contextMenuInterceptorScript = r'''
    (function(){
    "use strict";
    window.addEventListener('contextmenu', function(e) {
      if (window.dulceContextMenuEnabled === false) {
        return;
      }
      var target = e.target;
      var linkUrl = '';
      var imageUrl = '';
      var selectedText = window.getSelection().toString();
      var isEditable = target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable;

      var current = target;
      while (current) {
        if (current.tagName === 'A') {
          linkUrl = current.href;
          break;
        }
        current = current.parentNode;
      }

      if (target.tagName === 'IMG') {
        imageUrl = target.src;
      }

      var elementType = 'empty';
      if (linkUrl) {
        elementType = 'link';
      } else if (imageUrl) {
        elementType = 'image';
      } else if (selectedText) {
        elementType = 'selection';
      } else if (isEditable) {
        elementType = 'input';
      }

      e.preventDefault();

      try {
        window.chrome.webview.postMessage(JSON.stringify({
          type: 'contextmenu',
          x: e.clientX,
          y: e.clientY,
          elementType: elementType,
          linkUrl: linkUrl,
          imageUrl: imageUrl,
          selectedText: selectedText,
          isEditable: isEditable
        }));
      } catch (err) {}
    }, true);
    })();
  ''';

  // ── Script de enmascaramiento de huella digital ───────
  static const String fingerprintMaskScript = r'''
    (function(){
    "use strict";
    try {
      Object.defineProperty(navigator, 'plugins', {
        get: function() {
          var mockPlugins = [];
          mockPlugins.item = function() { return null; };
          mockPlugins.namedItem = function() { return null; };
          mockPlugins.refresh = function() {};
          return mockPlugins;
        }
      });
    } catch (e) {}
    try {
      Object.defineProperty(navigator, 'languages', {
        get: function() { return ['es-ES', 'es', 'en-US', 'en']; }
      });
    } catch (e) {}
    try {
      Object.defineProperty(navigator, 'webdriver', {
        get: function() { return false; }
      });
    } catch (e) {}
    try {
      var originalScreen = window.screen;
      Object.defineProperty(window, 'screen', {
        get: function() {
          return {
            availHeight: 1040,
            availWidth: 1920,
            colorDepth: 24,
            height: 1080,
            pixelDepth: 24,
            width: 1920,
            orientation: originalScreen.orientation
          };
        }
      });
    } catch (e) {}
    })();
  ''';

  // ── Script de Autocompletado de Credenciales ─────────────
  static const String autofillScript = r'''
    (function(){
    "use strict";

    var _activeInput = null;

    function checkFields(el) {
      if (!window.dulceAutofillEnabled) return;
      if (window.dulceIncognitoMode && window.dulceAutofillDisableInIncognito) return;

      if (el.tagName !== "INPUT") return;
      var type = (el.type || "").toLowerCase();
      var isCredField = type === "password" || type === "text" || type === "email";
      if (!isCredField) return;

      // Buscar si hay campo password cercano o dentro del mismo form
      var form = el.closest("form");
      var container = form || document;
      var hasPassword = container.querySelector("input[type='password']") !== null;
      if (!hasPassword) return;

      // Calcular rect
      var rect = el.getBoundingClientRect();
      
      try {
        window.chrome.webview.postMessage(JSON.stringify({
          type: "autofill_detected",
          domain: window.location.hostname,
          fieldTypes: [type],
          rect: {
            x: rect.left,
            y: rect.top,
            width: rect.width,
            height: rect.height
          }
        }));
      } catch(e) {}
    }

    document.addEventListener("focusin", function(e) {
      if (e.target && e.target.tagName === "INPUT") {
        _activeInput = e.target;
        checkFields(e.target);
      }
    }, true);

    document.addEventListener("focusout", function(e) {
      // Mandar despues de un pequeño timeout para ver si el foco va a otro input
      setTimeout(function() {
        if (document.activeElement && document.activeElement.tagName === "INPUT") {
          // Otro input enfocado, no cerrar
        } else {
          try {
            window.chrome.webview.postMessage(JSON.stringify({
              type: "autofill_dismiss"
            }));
          } catch(e) {}
        }
      }, 150);
    }, true);

    // Agregar manejador global para rellenar
    window.dulceFillCredentials = function(u, p) {
      var active = document.activeElement;
      var form = active ? active.closest("form") : null;
      var formOrDoc = form || document;

      var pwdInput = formOrDoc.querySelector("input[type='password']");
      var userInput = formOrDoc.querySelector("input[type='text'], input[type='email'], input[name*='user'], input[name*='login'], input[name*='email']");

      if (!userInput && active && active.type !== 'password') {
        userInput = active;
      }
      if (!pwdInput && active && active.type === 'password') {
        pwdInput = active;
      }

      function setValue(input, val) {
        if (!input) return;
        input.value = val;
        input.dispatchEvent(new Event('input', { bubbles: true }));
        input.dispatchEvent(new Event('change', { bubbles: true }));
        input.dispatchEvent(new Event('blur', { bubbles: true }));
      }

      setValue(userInput, u);
      setValue(pwdInput, p);
    };

    })();
  ''';

  // ── Script de Bloqueo Cosmético de Anuncios ───────────────
  // Oculta los contenedores de anuncios usando display:none.
  // Los selectores se inyectan mediante window.dulceCosmeticSelectors
  // desde Flutter (getCosmeticScript en CosmeticBlocker) antes de
  // ejecutar este script, por lo que es seguro y está acotado por dominio.
  //
  // SEGURIDAD:
  //   - Solo usa display:none con !important, no modifica JS ni eventos.
  //   - MutationObserver solo reacciona a addedNodes (no revisa todo el DOM).
  //   - No toca inputs, formularios ni reproductores de video.
  //   - El marcador data-dulceHidden evita trabajo redundante.
  static const String cosmeticBlockScript = r'''
    (function(){
    "use strict";

    var SELECTORS = window.dulceCosmeticSelectors || [];
    if (!SELECTORS.length) return;

    // Unir todos los selectores para una sola llamada querySelectorAll
    var combinedSel;
    try { combinedSel = SELECTORS.join(","); } catch(e) { return; }
    if (!combinedSel) return;

    function hideElements() {
      try {
        var elements = document.querySelectorAll(combinedSel);
        for (var i = 0; i < elements.length; i++) {
          var el = elements[i];
          if (!el.dataset.dulceHidden) {
            el.style.setProperty("display", "none", "important");
            el.dataset.dulceHidden = "1";
          }
        }
      } catch(e) {}
    }

    // Aplicar a los elementos ya presentes en el DOM
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", hideElements, { once: true });
    } else {
      hideElements();
    }

    // Observar cambios futuros (anuncios que cargan dinámicamente tras el scroll)
    var _timer = null;
    var _dulceObserver = new MutationObserver(function(mutations) {
      var hasNewNodes = false;
      for (var i = 0; i < mutations.length; i++) {
        if (mutations[i].addedNodes.length > 0) {
          hasNewNodes = true;
          break;
        }
      }
      if (hasNewNodes) {
        if (_timer) clearTimeout(_timer);
        _timer = setTimeout(hideElements, 250);
      }
    });

    _dulceObserver.observe(document.documentElement, {
      childList: true,
      subtree: true
    });

    })();
  ''';
}
