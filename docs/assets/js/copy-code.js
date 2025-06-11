document.addEventListener('DOMContentLoaded', function() {
    const codeBlocks = document.querySelectorAll('pre > code');

    codeBlocks.forEach(codeBlock => {
        const pre = codeBlock.parentNode;

        // Add single-line or multi-line class
        const lines = codeBlock.textContent.split('\n').length;
        codeBlock.classList.add(lines === 1 ? 'single-line' : 'multi-line');

        // Create copy button
        const button = document.createElement('button');
        button.className = 'copy-button';
        button.setAttribute('aria-label', 'Copy code');
        button.type = 'button';
        // Set default icon (matches CSS)
        button.style.backgroundImage = 'url("data:image/svg+xml;utf8,<svg xmlns=\'http://www.w3.org/2000/svg\' fill=\'none\' viewBox=\'0 0 16 16\'><rect width=\'10\' height=\'12\' x=\'3\' y=\'2\' stroke=\'%23666\' stroke-width=\'1.5\' rx=\'2\'/><path stroke=\'%23666\' stroke-width=\'1.5\' d=\'M6 2V1a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v1\'/></svg>")';

        // Insert button as first child of <pre>
        pre.style.position = 'relative';
        pre.insertBefore(button, codeBlock);

        button.addEventListener('click', async () => {
            try {
                await navigator.clipboard.writeText(codeBlock.textContent);
                // Show check mark
                button.style.backgroundImage = 'url("data:image/svg+xml;utf8,<svg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'0 0 16 16\'><path fill=\'%23008800\' d=\'M6.003 11.414l-3.707-3.707 1.414-1.414L6 8.586l6.293-6.293 1.414 1.414z\'/></svg>")';
                setTimeout(() => {
                    // Restore default icon
                    button.style.backgroundImage = 'url("data:image/svg+xml;utf8,<svg xmlns=\'http://www.w3.org/2000/svg\' fill=\'none\' viewBox=\'0 0 16 16\'><rect width=\'10\' height=\'12\' x=\'3\' y=\'2\' stroke=\'%23666\' stroke-width=\'1.5\' rx=\'2\'/><path stroke=\'%23666\' stroke-width=\'1.5\' d=\'M6 2V1a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v1\'/></svg>")';
                }, 1500);
            } catch (err) {
                // Show error icon
                button.style.backgroundImage = 'url("data:image/svg+xml;utf8,<svg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'0 0 16 16\'><circle cx=\'8\' cy=\'8\' r=\'7\' fill=\'%23d32\'/><text x=\'8\' y=\'12\' text-anchor=\'middle\' font-size=\'10\' fill=\'white\'>!</text></svg>")';
                setTimeout(() => {
                    button.style.backgroundImage = 'url("data:image/svg+xml;utf8,<svg xmlns=\'http://www.w3.org/2000/svg\' fill=\'none\' viewBox=\'0 0 16 16\'><rect width=\'10\' height=\'12\' x=\'3\' y=\'2\' stroke=\'%23666\' stroke-width=\'1.5\' rx=\'2\'/><path stroke=\'%23666\' stroke-width=\'1.5\' d=\'M6 2V1a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v1\'/></svg>")';
                }, 3000);
            }
        });
    });
});