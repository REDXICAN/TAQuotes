// Fix missing thumbnails by using screenshot fallbacks
const updateMissingThumbnails = () => {
  const fallbacks = {
    "CRT-77-1R-N": {
      thumbnailUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FCRT-77-1R-N%2FCRT-77-1R-N%20P.1.png?alt=media",
      imageUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FCRT-77-1R-N%2FCRT-77-1R-N%20P.1.png?alt=media"
    },
    "CRT-77-2R-N": {
      thumbnailUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FCRT-77-2R-N%2FCRT-77-2R-N%20P.1.png?alt=media",
      imageUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FCRT-77-2R-N%2FCRT-77-2R-N%20P.1.png?alt=media"
    },
    "M3H24-1": {
      thumbnailUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FM3H24-1%2FM3H24-1%20P.1.png?alt=media",
      imageUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FM3H24-1%2FM3H24-1%20P.1.png?alt=media"
    },
    "M3H47-2": {
      thumbnailUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FM3H47-2%2FM3H47-2%20P.1.png?alt=media",
      imageUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FM3H47-2%2FM3H47-2%20P.1.png?alt=media"
    },
    "PST-48-18-D2R(L)-FB-N": {
      thumbnailUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FPST-48-18-D2R(L)-FB-N%2FPST-48-18-D2R(L)-FB-N%20P.1.png?alt=media",
      imageUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FPST-48-18-D2R(L)-FB-N%2FPST-48-18-D2R(L)-FB-N%20P.1.png?alt=media"
    },
    "PST-48-18-D2R(L)-N": {
      thumbnailUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FPST-48-18-D2R(L)-N%2FPST-48-18-D2R(L)-N%20P.1.png?alt=media",
      imageUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FPST-48-18-D2R(L)-N%2FPST-48-18-D2R(L)-N%20P.1.png?alt=media"
    },
    "PST-48-D2R(L)-FB-N": {
      thumbnailUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FPST-48-D2R(L)-FB-N%2FPST-48-D2R(L)-FB-N%20P.1.png?alt=media",
      imageUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FPST-48-D2R(L)-FB-N%2FPST-48-D2R(L)-FB-N%20P.1.png?alt=media"
    },
    "PST-48-D2R(L)-N": {
      thumbnailUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FPST-48-D2R(L)-N%2FPST-48-D2R(L)-N%20P.1.png?alt=media",
      imageUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FPST-48-D2R(L)-N%2FPST-48-D2R(L)-N%20P.1.png?alt=media"
    },
    "PST-60-24-D2R(L)-FB-N": {
      thumbnailUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FPST-60-24-D2R(L)-FB-N%2FPST-60-24-D2R(L)-FB-N%20P.1.png?alt=media",
      imageUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FPST-60-24-D2R(L)-FB-N%2FPST-60-24-D2R(L)-FB-N%20P.1.png?alt=media"
    },
    "PST-60-24-D2R(L)-N": {
      thumbnailUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FPST-60-24-D2R(L)-N%2FPST-60-24-D2R(L)-N%20P.1.png?alt=media",
      imageUrl: "https://firebasestorage.googleapis.com/v0/b/taquotes.firebasestorage.app/o/screenshots%2FPST-60-24-D2R(L)-N%2FPST-60-24-D2R(L)-N%20P.1.png?alt=media"
    },
  };
  
  // Apply fallbacks in your image widget
  const getProductImage = (sku) => {
    return fallbacks[sku] || null;
  };
};
