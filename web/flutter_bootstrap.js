{{flutter_js}}
{{flutter_build_config}}

// Flutter has nothing to paint until the engine + app bundle (several MB)
// finish downloading and initializing, so a cold load is otherwise a blank
// page for a few seconds. This boot screen fills that gap; it's removed the
// moment the app takes over. Colors mirror AppTheme's teal seed (see
// lib/core/theme.dart) so there's no flash-of-wrong-brand-color between this
// and the real UI.
const loading = document.createElement('div');
loading.id = 'tally-boot';
loading.innerHTML = `
  <style>
    #tally-boot {
      position: fixed;
      inset: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #fbfefc;
    }
    @media (prefers-color-scheme: dark) {
      #tally-boot { background: #0f1413; }
    }
    #tally-boot .spinner {
      width: 32px;
      height: 32px;
      border-radius: 50%;
      border: 3px solid rgba(0, 137, 123, 0.25);
      border-top-color: #00897B;
      animation: tally-boot-spin 0.8s linear infinite;
    }
    @keyframes tally-boot-spin {
      to { transform: rotate(360deg); }
    }
  </style>
  <div class="spinner" role="status" aria-label="Loading Tally"></div>
`;
document.body.appendChild(loading);

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    loading.remove();
  },
});
