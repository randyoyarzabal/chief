document.addEventListener('DOMContentLoaded', function() {
    // Create copy buttons for all code blocks
    const codeBlocks = document.querySelectorAll('pre.highlight');
    
    codeBlocks.forEach(block => {
        // Create copy button
        const button = document.createElement('button');
        button.className = 'copy-button';
        button.textContent = 'Copy';
        
        // Add tooltip container
        const tooltip = document.createElement('span');
        tooltip.className = 'tooltip';
        tooltip.textContent = 'Copied!';
        button.appendChild(tooltip);
        
        // Add button to code block
        const wrapper = document.createElement('div');
        wrapper.className = 'code-wrapper';
        wrapper.appendChild(button);
        wrapper.appendChild(block);
        block.parentNode.replaceChild(wrapper, block);
        
        // Add click handler
        button.addEventListener('click', async () => {
            try {
                await navigator.clipboard.writeText(block.textContent);
                
                // Show copied status
                tooltip.textContent = 'Copied!';
                tooltip.classList.add('visible');
                
                // Reset after delay
                setTimeout(() => {
                    tooltip.textContent = 'Copy';
                    tooltip.classList.remove('visible');
                }, 2000);
            } catch (err) {
                console.error('Failed to copy:', err);
                tooltip.textContent = 'Failed!';
                tooltip.classList.add('visible');
                
                setTimeout(() => {
                    tooltip.classList.remove('visible');
                }, 2000);
            }
        });
    });
});