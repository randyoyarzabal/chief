document.addEventListener('DOMContentLoaded', function() {
    const copyButtons = document.querySelectorAll('.copy-button');
    
    copyButtons.forEach(button => {
        button.addEventListener('click', async () => {
            const pre = button.parentElement;
            const code = pre.querySelector('code').textContent;
            
            try {
                await navigator.clipboard.writeText(code);
                
                // Add copied class for animation
                button.classList.add('copied');
                
                // Remove class after animation completes
                setTimeout(() => {
                    button.classList.remove('copied');
                }, 300); // Matches transition duration
            } catch (err) {
                console.error('Failed to copy:', err);
            }
        });
    });
});