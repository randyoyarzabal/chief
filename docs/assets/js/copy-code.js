document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.highlight').forEach(codeBlock => {
    const container = document.createElement('div');
    container.className = 'copy-button-container';
    
    const copyBtn = document.createElement('button');
    copyBtn.className = 'copy-button';
    copyBtn.setAttribute('aria-label', 'Copy code');
    
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('stroke', 'currentColor');
    svg.setAttribute('stroke-width', '2');
    svg.innerHTML = `
      <path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
    `;
    
    const copiedSvg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    copiedSvg.setAttribute('viewBox', '0 0 24 24');
    copiedSvg.setAttribute('fill', 'none');
    copiedSvg.setAttribute('stroke', 'currentColor');
    copiedSvg.setAttribute('stroke-width', '2');
    copiedSvg.style.display = 'none';
    copiedSvg.innerHTML = `
      <path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
      <path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
    `;
    
    copyBtn.appendChild(svg);
    copyBtn.appendChild(copiedSvg);
    
    container.appendChild(codeBlock);
    container.insertBefore(copyBtn, container.firstChild);
    codeBlock.parentNode.replaceChild(container, codeBlock);
    
    copyBtn.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(codeBlock.textContent);
        svg.style.display = 'none';
        copiedSvg.style.display = 'block';
        copyBtn.classList.add('copied');
        
        setTimeout(() => {
          svg.style.display = 'block';
          copiedSvg.style.display = 'none';
          copyBtn.classList.remove('copied');
        }, 2000);
      } catch (err) {
        console.error('Failed to copy:', err);
      }
    });
  });
});