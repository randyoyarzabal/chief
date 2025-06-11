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

        // Insert button as first child of <pre>
        pre.style.position = 'relative';
        pre.insertBefore(button, codeBlock);

        button.addEventListener('click', async () => {
            try {
                await navigator.clipboard.writeText(codeBlock.textContent);
                button.classList.remove('copy-error');
                button.classList.add('copied');
                setTimeout(() => {
                    button.classList.remove('copied');
                }, 1500);
            } catch (err) {
                button.classList.remove('copied');
                button.classList.add('copy-error');
                setTimeout(() => {
                    button.classList.remove('copy-error');
                }, 3000);
            }
        });
    });
});