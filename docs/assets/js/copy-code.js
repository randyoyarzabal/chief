document.addEventListener('DOMContentLoaded', function() {
    const codeBlocks = document.querySelectorAll('pre > code');
    
    codeBlocks.forEach(codeBlock => {
        const wrapper = document.createElement('div');
        wrapper.className = 'code-block';
        
        const button = document.createElement('button');
        button.className = 'copy-button';
        button.setAttribute('aria-label', 'Copy code');
        
        const parent = codeBlock.parentNode;
        parent.replaceChild(wrapper, codeBlock);
        wrapper.appendChild(codeBlock);
        wrapper.insertBefore(button, codeBlock);
        
        const lines = codeBlock.textContent.split('\n').length;
        codeBlock.classList.add(lines === 1 ? 'single-line' : 'multi-line');
        
        button.addEventListener('click', async () => {
            try {
                await navigator.clipboard.writeText(codeBlock.textContent);
                // Add copied state feedback
                button.style.backgroundImage = 'url("data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="%23088" d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2h2l2 2h14a2 2 0 0 1 2 2z"/></svg>")';
                
                setTimeout(() => {
                    button.style.backgroundImage = 'url("data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="%23666" d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"/></svg>")';
                }, 2000);
            } catch (err) {
                console.error('Failed to copy:', err);
                // Add error state feedback
                button.style.backgroundImage = 'url("data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="%23d32" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg>")';
                
                setTimeout(() => {
                    button.style.backgroundImage = 'url("data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="%23666" d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"/></svg>")';
                }, 3000);
            }
        });
    });
});