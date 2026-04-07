"use sctrict";

window.$docsify = {
  name: "res-scrapy",
  repo: "https://github.com/MetalbolicX/res-scrapy.git",
  loadSidebar: true,
  executeScript:false,
  subMaxLevel: 3,
  coverpage: true,
  tabs: {
    persist: true,
    sync: true,
    theme: "classic",
    tabComments: true,
    tabHeadings: true,
  },
  search: {
    noData: "No results found",
    paths: ["/api-reference"],
    placeholder: "Search...",
    depth: 2,
    maxAge: 86400000, // 1 day
  },
  "flexible-alerts": {
    style: "flat"
  }
};
