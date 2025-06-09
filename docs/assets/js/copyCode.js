document.addEventListener('DOMContentLoaded', function () {
  document.querySelectorAll('pre > code').forEach(function (codeBlock) {
    var button = document.createElement('button');
    button.className = 'copy-code-button';
    button.type = 'button';
    button.innerText = 'Copy';

    button.addEventListener('click', function () {
      navigator.clipboard.writeText(codeBlock.innerText).then(function () {
        button.innerText = 'Copied!';
        setTimeout(function () {
          button.innerText = 'Copy';
        }, 2000);
      });
    });

    var pre = codeBlock.parentNode;
    pre.parentNode.insertBefore(button, pre);
  });
});