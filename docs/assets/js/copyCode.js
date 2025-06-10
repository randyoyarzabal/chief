document.addEventListener('DOMContentLoaded', function() {
    // Create copy buttons for all code blocks
    const codeBlocks = document.querySelectorAll('pre.highlight');
    codeBlocks.forEach(block => {
        // Create button container
        const buttonContainer = document.createElement('div');
        buttonContainer.className = 'copy-button-container';
        
        // Create copy button
        const copyButton = document.createElement('button');
        copyButton.textContent = 'Copy';
        copyButton.className = 'copy-button';
        copyButton.setAttribute('aria-label', 'Copy code to clipboard');
        
        // Add event listener for copy functionality
        copyButton.addEventListener('click', async () => {
            try {
                await navigator.clipboard.writeText(block.querySelector('code').textContent);
                copyButton.textContent = 'Copied!';
                setTimeout(() => {
                    copyButton.textContent = 'Copy';
                }, 2000);
            } catch (err) {
                console.error('Failed to copy:', err);
                copyButton.textContent = 'Error';
            }
        });
        
        buttonContainer.appendChild(copyButton);
        block.insertBefore(buttonContainer, block.firstChild);
    });
});