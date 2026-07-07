// ponytail: leading-integer page-label heuristic; the pilot spot-checks 10
// random pages against the physical book (amendment 6) and the per-volume
// monotonic assertion catches drift. Upgrade to a labelled-index parse only
// if the pilot shows the heuristic misreads material pages.
export function buildPageMap(index, { volumes }) {
  const errors = [];
  const entries = []; // ordered [{pdfPage, bookPage}] across all volumes

  volumes.forEach((volume, i) => {
    const endPdfPage = volumes[i + 1]
      ? volumes[i + 1].startPdfPage - 1
      : Infinity;
    const pages = index.filter(
      (p) => p.pdf_page >= volume.startPdfPage && p.pdf_page <= endPdfPage,
    );

    let prev = null;
    for (const p of pages) {
      const match = p.text.match(/^\s*(\d+)\b/);
      if (!match) continue; // page's own label did not parse - skip it
      const bookPage = Number(match[1]);
      if (prev !== null && bookPage <= prev.bookPage) {
        errors.push(
          `volume ${i + 1}: non-monotonic book page ${bookPage} at pdf ` +
            `page ${p.pdf_page} (follows ${prev.bookPage} at pdf page ${prev.pdfPage})`,
        );
      }
      prev = { bookPage, pdfPage: p.pdf_page };
      entries.push(prev);
    }
  });

  function bookToPdf(bookPage) {
    let nearest = null;
    for (const e of entries) {
      if (e.bookPage === bookPage) return e.pdfPage;
      if (
        e.bookPage < bookPage &&
        (!nearest || e.bookPage > nearest.bookPage)
      ) {
        nearest = e;
      }
    }
    return nearest?.pdfPage;
  }

  return { bookToPdf, validate: () => errors };
}
