// Updated JavaScript for fade-out animation
document.addEventListener('DOMContentLoaded', function() {
    const codeBlocks = document.querySelectorAll('pre.highlight');
    codeBlocks.forEach(block => {
        const buttonContainer = document.createElement('div');
        buttonContainer.className = 'copy-button-container';
        
        const copyButton = document.createElement('button');
        copyButton.textContent = 'Copy';
        copyButton.className = 'copy-button github-style';
        copyButton.setAttribute('aria-label', 'Copy code to clipboard');
        
        copyButton.addEventListener('click', async () => {
            try {
                await navigator.clipboard.writeText(block.querySelector('code').textContent);
                copyButton.classList.add('copied');
                
                // Remove animation class after fade out
                setTimeout(() => {
                    copyButton.classList.remove('copied');
                }, 1000);
            } catch (err) {
                console.error('Failed to copy:', err);
                copyButton.textContent = 'Error';
            }
        });
        
        buttonContainer.appendChild(copyButton);
        block.insertBefore(buttonContainer, block.firstChild);
    });
});