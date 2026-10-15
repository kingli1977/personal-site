// 往期文章。每项只保留 title 与 url，按需增删。
const articles = [
  { title: "【文章标题一】", url: "https://example.com/article-1" },
  { title: "【文章标题二】", url: "https://example.com/article-2" },
  { title: "【文章标题三】", url: "https://example.com/article-3" },
];

const list = document.querySelector("#article-list");

articles.forEach((article) => {
  const item = document.createElement("li");
  const link = document.createElement("a");
  link.href = article.url;

  const title = document.createElement("span");
  title.className = "article-title";
  title.textContent = article.title;

  const arrow = document.createElement("span");
  arrow.className = "article-arrow";
  arrow.setAttribute("aria-hidden", "true");
  arrow.innerHTML =
    '<svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M3 7h8M8 3.5 11.5 7 8 10.5" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  link.append(title, arrow);
  item.append(link);
  list.append(item);
});
