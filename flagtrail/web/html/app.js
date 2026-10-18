// DoppioMart storefront - cosmetic only
(function () {
  document.querySelectorAll('a[href^="/#"]').forEach(function (a) {
    a.addEventListener('click', function (e) {
      var id = a.getAttribute('href').slice(2);
      var el = document.getElementById(id);
      if (el) { e.preventDefault(); el.scrollIntoView({ behavior: 'smooth' }); }
    });
  });
  var y = new Date().getFullYear();
  var f = document.querySelector('footer p');
  if (f) { f.textContent = f.textContent.replace('©', '© ' + y); }
})();
