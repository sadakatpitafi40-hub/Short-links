import React, { useEffect, useState } from "react";

// Single-file React app (App.jsx)
// Tailwind classes used — if you deploy with Vite/CRA, make sure Tailwind is configured.
// Purpose: gallery with title+description, short URL support, 3-second ad overlay before showing original.

const IMAGES = [
  {
    id: "sunset",
    title: "Golden Sunset",
    description: "A warm golden sunset over the sea.",
    thumb: "https://images.unsplash.com/photo-1501973801540-537f08ccae7b?w=600&q=80&auto=format&fit=crop",
    original: "https://images.unsplash.com/photo-1501973801540-537f08ccae7b?w=2400&q=90&auto=format&fit=crop",
    short: "gldn",
  },
  {
    id: "forest",
    title: "Misty Forest",
    description: "Morning mist drifting between tall pines.",
    thumb: "https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=600&q=80&auto=format&fit=crop",
    original: "https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=2400&q=90&auto=format&fit=crop",
    short: "mstf",
  },
  {
    id: "city",
    title: "City Lights",
    description: "Night skyline with bright city lights.",
    thumb: "https://images.unsplash.com/photo-1467269204594-9661b134dd2b?w=600&q=80&auto=format&fit=crop",
    original: "https://images.unsplash.com/photo-1467269204594-9661b134dd2b?w=2400&q=90&auto=format&fit=crop",
    short: "ctyl",
  },
];

function getImageByShort(key) {
  return IMAGES.find((i) => i.short === key || i.id === key) || null;
}

export default function App() {
  const [selected, setSelected] = useState(null);
  const [showAd, setShowAd] = useState(false);
  const [adCountdown, setAdCountdown] = useState(3);
  const [copyMsg, setCopyMsg] = useState("");

  // read short URL from hash like #/s/gldn or #/img/sunet
  useEffect(() => {
    function checkHash() {
      const h = window.location.hash || "";
      const m = h.match(/#\/?s\/(\w+)/i) || h.match(/#\/?img\/(\w+)/i);
      if (m) {
        const key = m[1];
        const img = getImageByShort(key);
        if (img) {
          openImage(img);
        }
      }
    }
    checkHash();
    window.addEventListener("hashchange", checkHash);
    return () => window.removeEventListener("hashchange", checkHash);
  }, []);

  // open image: show 3-second ad, then show original
  function openImage(img) {
    setSelected(img);
    setShowAd(true);
    setAdCountdown(3);
    // clear any existing timers by using a local counter
    let sec = 3;
    const interval = setInterval(() => {
      sec -= 1;
      setAdCountdown(sec);
      if (sec <= 0) {
        clearInterval(interval);
        setShowAd(false);
      }
    }, 1000);
  }

  function makeShortLink(img) {
    const base = window.location.origin + window.location.pathname;
    return `${base}#/s/${img.short}`;
  }

  async function copyShort(img) {
    const link = makeShortLink(img);
    try {
      await navigator.clipboard.writeText(link);
      setCopyMsg("Short link copied!");
      setTimeout(() => setCopyMsg(""), 2000);
    } catch (e) {
      setCopyMsg("Could not copy — manually copy:\n" + link);
    }
  }

  // set page title & meta description when selected
  useEffect(() => {
    if (selected) {
      document.title = `${selected.title} — My Gallery`;
      const desc = document.querySelector('meta[name="description"]');
      if (desc) desc.setAttribute("content", selected.description);
      else {
        const m = document.createElement("meta");
        m.name = "description";
        m.content = selected.description;
        document.head.appendChild(m);
      }
    } else {
      document.title = "My Gallery";
    }
  }, [selected]);

  return (
    <div className="min-h-screen bg-slate-50 p-6">
      <header className="max-w-5xl mx-auto mb-6">
        <h1 className="text-3xl font-bold">My GitHub Gallery</h1>
        <p className="text-slate-600">Title, description, short URLs, gallery, and 3s ad before original.</p>
      </header>

      <main className="max-w-5xl mx-auto">
        <section className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-6">
          {IMAGES.map((img) => (
            <article key={img.id} className="bg-white rounded-2xl shadow p-3">
              <img
                src={img.thumb}
                alt={img.title}
                className="w-full h-44 object-cover rounded-lg cursor-pointer"
                onClick={() => {
                  // set hash for short-link behavior
                  window.location.hash = `#/s/${img.short}`;
                  openImage(img);
                }}
              />
              <h3 className="mt-3 font-semibold">{img.title}</h3>
              <p className="text-sm text-slate-500">{img.description}</p>

              <div className="mt-3 flex items-center justify-between">
                <button
                  className="text-sm px-3 py-1 rounded-lg border"
                  onClick={() => {
                    // open short link in new tab (works because hash includes short key)
                    window.open(makeShortLink(img), "_blank");
                  }}
                >
                  Open (short URL)
                </button>
                <button className="text-sm px-3 py-1 rounded-lg border" onClick={() => copyShort(img)}>
                  Copy Short
                </button>
              </div>
              {copyMsg && <div className="mt-2 text-xs text-green-600">{copyMsg}</div>}
            </article>
          ))}
        </section>

        {/* Lightbox / Modal */}
        {selected && (
          <div className="fixed inset-0 z-40 flex items-center justify-center">
            <div className="absolute inset-0 bg-black/50" onClick={() => { setSelected(null); window.location.hash = ''; }} />

            <div className="relative z-50 max-w-4xl w-full mx-4">
              <div className="bg-white rounded-2xl overflow-hidden shadow-lg">
                <div className="p-4">
                  <h2 className="text-xl font-semibold">{selected.title}</h2>
                  <p className="text-sm text-slate-600">{selected.description}</p>
                </div>

                <div className="w-full h-[60vh] bg-black flex items-center justify-center">
                  {/* Ad overlay or original image */}
                  {showAd ? (
                    <div className="w-full h-full flex flex-col items-center justify-center text-white">
                      <div className="text-sm mb-2">Sponsored ad — closing in</div>
                      <div className="text-6xl font-bold">{adCountdown}</div>
                      <div className="mt-4 text-xs">(This simulates a 3-second ad. Replace with your ad creative.)</div>
                    </div>
                  ) : (
                    <img src={selected.original} alt={selected.title} className="w-full h-full object-contain" />
                  )}
                </div>

                <div className="p-4 flex items-center justify-between">
                  <div className="text-sm text-slate-600">Original: <span className="font-medium">{selected.id}</span></div>
                  <div className="flex gap-2">
                    <a href={selected.original} target="_blank" rel="noreferrer" className="px-3 py-1 border rounded">Open Original</a>
                    <button className="px-3 py-1 border rounded" onClick={() => { setSelected(null); window.location.hash = ''; }}>Close</button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>

      <footer className="max-w-5xl mx-auto mt-8 text-sm text-slate-500">
        <p>Made for GitHub Pages. Deploy as static site. Update IMAGES array for your photos, titles, descriptions and short keys.</p>
      </footer>
    </div>
  );
}
