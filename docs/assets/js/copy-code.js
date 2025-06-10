document.addEventListener('DOMContentLoaded', function() {
    const codeBlocks = document.querySelectorAll('pre.highlight');
    codeBlocks.forEach(block => {
        const buttonContainer = document.createElement('div');
        buttonContainer.className = 'copy-button-container';
        
        const copyButton = document.createElement('button');
        copyButton.className = 'copy-button phind-style';
        copyButton.setAttribute('aria-label', 'Copy code to clipboard');
        
        // Create centered SVG checkmark
        const svgNS = "http://www.w3.org/2000/svg";
        const svg = document.createElementNS(svgNS, "svg");
        svg.setAttribute("viewBox", "0 0 24 24");
        svg.setAttribute("width", "16");
        svg.setAttribute("height", "16");
        svg.style.position = "absolute";
        svg.style.top = "50%";
        svg.style.left = "50%";
        svg.style.transform = "translate(-50%, -50%)";
        svg.style.opacity = "0";
        
        const path = document.createElementNS(svgNS, "path");
        path.setAttribute("d", "M9 16.17L4.83 12l1.42-1.41L9 14.17l4.75-4.75L13.41 12L9 16.17z");
        path.setAttribute("fill", "currentColor");
        
        svg.appendChild(path);
        copyButton.appendChild(svg);
        
        copyButton.addEventListener('click', async () => {
            try {
                await navigator.clipboard.writeText(block.querySelector('code').textContent);
                copyButton.classList.add('copied');
                
                // Reset after animation completes
                setTimeout(() => {
                    copyButton.classList.remove('copied');
                }, 1500);
            } catch (err) {
                console.error('Failed to copy:', err);
                copyButton.classList.add('error');
                
                // Reset error state
                setTimeout(() => {
                    copyButton.classList.remove('error');
                }, 1000);
            }
        });
        
        buttonContainer.appendChild(copyButton);
        block.insertBefore(buttonContainer, block.firstChild);
    });
});