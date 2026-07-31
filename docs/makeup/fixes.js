const MIRROR_CAPTURE_FILE = 'camera-mirror.jpg';

function installMirrorCamera() {
  const style = document.createElement('style');
  style.textContent = '#camera{transform:scaleX(-1);transform-origin:center center}';
  document.head.appendChild(style);

  const captureButton = document.querySelector('#captureBtn');
  const video = document.querySelector('#camera');
  const canvas = document.querySelector('#cameraCanvas');
  const fileInput = document.querySelector('#fileInput');
  const cameraDialog = document.querySelector('#cameraDialog');

  if (!captureButton || !video || !canvas || !fileInput) return;

  captureButton.addEventListener('click', (event) => {
    event.preventDefault();
    event.stopImmediatePropagation();

    if (!video.videoWidth || !video.videoHeight) return;

    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    const context = canvas.getContext('2d');
    context.save();
    context.translate(canvas.width, 0);
    context.scale(-1, 1);
    context.drawImage(video, 0, 0, canvas.width, canvas.height);
    context.restore();

    canvas.toBlob((blob) => {
      if (!blob) return;
      try {
        const file = new File([blob], MIRROR_CAPTURE_FILE, { type: 'image/jpeg' });
        const transfer = new DataTransfer();
        transfer.items.add(file);
        fileInput.files = transfer.files;
        fileInput.dispatchEvent(new Event('change', { bubbles: true }));
      } catch (error) {
        console.error('镜像自拍写入失败', error);
      } finally {
        const activeStream = video.srcObject;
        if (activeStream) activeStream.getTracks().forEach((track) => track.stop());
        video.srcObject = null;
        if (cameraDialog?.open) cameraDialog.close();
      }
    }, 'image/jpeg', 0.92);
  }, true);
}

function getXiaohongshuKeyword(card) {
  const handle = card.querySelector('.handle')?.textContent?.trim() || '';
  const name = card.querySelector('.creator-name')?.textContent?.trim() || '';
  return handle.replace(/^小红书搜索[：:]\s*/, '').trim() || name;
}

function openXiaohongshuSearch(keyword) {
  const encoded = encodeURIComponent(keyword);
  const appSearch = `xhsdiscover://search/result?keyword=${encoded}&source=makeup_reference`;
  const browserFallback = `https://www.baidu.com/s?wd=${encodeURIComponent(`site:xiaohongshu.com ${keyword} 小红书`)}`;
  let appOpened = false;

  const markOpened = () => {
    if (document.hidden) appOpened = true;
  };
  document.addEventListener('visibilitychange', markOpened);

  try {
    navigator.clipboard?.writeText(keyword).catch(() => {});
  } catch (_) {}

  window.location.href = appSearch;
  window.setTimeout(() => {
    document.removeEventListener('visibilitychange', markOpened);
    if (!appOpened && document.visibilityState === 'visible') {
      window.location.href = browserFallback;
    }
  }, 1400);
}

function installXiaohongshuSearchLinks() {
  document.addEventListener('click', (event) => {
    const link = event.target.closest('.creator-link');
    if (!link) return;
    const card = link.closest('.creator-card');
    if (!card) return;
    const isXiaohongshu = [...card.querySelectorAll('.platform')]
      .some((item) => item.textContent.trim() === '小红书');
    if (!isXiaohongshu) return;

    event.preventDefault();
    event.stopImmediatePropagation();
    const keyword = getXiaohongshuKeyword(card);
    if (keyword) openXiaohongshuSearch(keyword);
  }, true);
}

installMirrorCamera();
installXiaohongshuSearchLinks();
