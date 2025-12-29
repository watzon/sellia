// Copy code functionality
function copyCode(btn) {
  const code = btn.closest('.code-block').querySelector('.code-body').textContent;
  navigator.clipboard.writeText(code.trim()).then(() => {
    const originalText = btn.textContent;
    btn.textContent = 'Copied!';
    btn.style.color = 'var(--crystal-light)';
    btn.style.borderColor = 'var(--crystal-primary)';
    setTimeout(() => {
      btn.textContent = originalText;
      btn.style.color = '';
      btn.style.borderColor = '';
    }, 2000);
  });
}

// Subtle parallax on crystal shards
document.addEventListener('mousemove', (e) => {
  const shards = document.querySelectorAll('.crystal-shard');
  const x = (e.clientX / window.innerWidth - 0.5) * 20;
  const y = (e.clientY / window.innerHeight - 0.5) * 20;

  shards.forEach((shard, i) => {
    const factor = (i + 1) * 0.3;
    shard.style.transform = `translate(${x * factor}px, ${y * factor}px)`;
  });
});
