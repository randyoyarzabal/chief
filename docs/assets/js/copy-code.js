document.addEventListener('DOMContentLoaded', function() {
    // Add copy buttons to all code blocks
    const codeBlocks = document.querySelectorAll('pre > code');
    codeBlocks.forEach(codeBlock => {
        const wrapper = document.createElement('div');
        wrapper.className = 'code-block';
        
        const button = document.createElement('button');
        button.className = 'copy-button';
        button.textContent = 'Copy';
        button.setAttribute('aria-label', 'Copy code');
        
        const parent = codeBlock.parentNode;
        parent.replaceChild(wrapper, codeBlock);
        wrapper.appendChild(codeBlock);
        wrapper.insertBefore(button, codeBlock);
        
        button.addEventListener('click', async () => {
            try {
                await navigator.clipboard.writeText(codeBlock.textContent);
                button.textContent = 'Copied!';
                setTimeout(() => {
                    button.textContent = 'Copy';
                }, 2000);
            } catch (err) {
                console.error('Failed to copy:', err);
                button.textContent = 'Error';
            }
        });
    });
});