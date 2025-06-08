// This assumes that you're using Rouge; if not, update the selector
const codeBlocks = document.querySelectorAll('.code-header + .highlighter-rouge');
const copyCodeButtons = document.querySelectorAll('.copy-code-button');

copyCodeButtons.forEach((copyCodeButton, index) => {
  const codeBlock = codeBlocks[index];

  copyCodeButton.addEventListener('click', () => {
    const textToCopy = codeBlock.textContent;
    navigator.clipboard.writeText(textToCopy)
      .then(() => {
        // Optional: Provide feedback to the user
        copyCodeButton.textContent = 'Copied!';
        setTimeout(() => {
          copyCodeButton.textContent = 'Copy code to clipboard';
        }, 2000); // Reset the button text after 2 seconds
      })
      .catch(err => {
        console.error('Failed to copy text: ', err);
      });
  });
});