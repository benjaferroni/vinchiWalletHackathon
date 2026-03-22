(function() {
  const style = document.createElement('style');
  style.innerHTML = `
    #vinchi-clover-trigger {
      position: fixed;
      top: 50%;
      right: 0;
      transform: translateY(-50%);
      background: #00a651;
      color: #fff;
      border: 1px solid #008c43;
      border-right: none;
      padding: 12px 16px;
      border-radius: 8px 0 0 8px;
      cursor: pointer;
      font-weight: 600;
      box-shadow: -2px 0 10px rgba(0,0,0,0.3);
      z-index: 9998;
      font-family: 'Inter', sans-serif;
      font-size: 14px;
      transition: background 0.2s;
    }
    #vinchi-clover-trigger:hover { background: #008c43; }

    #vinchi-pos-fullscreen {
      position: fixed;
      top: 0;
      left: 0;
      width: 100vw;
      height: 100vh;
      z-index: 10000;
      display: none;
      background: rgba(0,0,0,0.6);
      backdrop-filter: blur(5px);
    }
    #vinchi-pos-fullscreen.active { display: block; }

    #vinchi-pos-iframe {
      width: 100%;
      height: 100%;
      border: none;
    }
  `;
  document.head.appendChild(style);

  const triggerEl = document.createElement('button');
  triggerEl.id = 'vinchi-clover-trigger';
  triggerEl.innerText = '💳 Clover POS';
  triggerEl.onclick = () => VinchiClover.openPOS();
  document.body.appendChild(triggerEl);

  const posOverlay = document.createElement('div');
  posOverlay.id = 'vinchi-pos-fullscreen';
  // Use IFRAME to load full complex UI safely
  posOverlay.innerHTML = `<iframe id="vinchi-pos-iframe" src="clover.html"></iframe>`;
  document.body.appendChild(posOverlay);

  window.VinchiClover = {
    openPOS: () => {
      document.getElementById('vinchi-pos-fullscreen').classList.add('active');
    },
    closePOS: () => {
      document.getElementById('vinchi-pos-fullscreen').classList.remove('active');
    }
  };
})();
