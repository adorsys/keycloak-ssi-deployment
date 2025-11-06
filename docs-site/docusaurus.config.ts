// docs-site/docusaurus.config.ts
import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';

const config: Config = {
  title: 'keycloak-ssi-deployment',
  favicon: 'img/favicon.ico',

  // IMPORTANT: org "adorsys" and project page baseUrl
  url: 'https://adorsys.github.io',
  baseUrl: '/keycloak-ssi-deployment/',

  // Where Pages will publish the static files
  deploymentBranch: 'gh-pages',

  // Optional, keep either true or false consistently
  trailingSlash: false,

  organizationName: 'adorsys',
  projectName: 'keycloak-ssi-deployment',

  i18n: { defaultLocale: 'en', locales: ['en'] },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          editUrl:
            'https://github.com/adorsys/keycloak-ssi-deployment/edit/main/docs-site/',
        },
        blog: false,
        theme: { customCss: './src/css/custom.css' },
      },
    ],
  ],

  themeConfig: {
    navbar: {
      title: 'Keycloak SSI Deployment',
      logo: { alt: 'Logo', src: 'img/logo.svg' },
      items: [
        { to: '/docs/intro', label: 'Docs', position: 'left' },
        { href: 'https://github.com/adorsys/keycloak-ssi-deployment', label: 'GitHub', position: 'right' },
      ],
    },
    footer: {
      style: 'dark',
      links: [],
      copyright: `© ${new Date().getFullYear()} adorsys`,
    },
    prism: { theme: prismThemes.github, darkTheme: prismThemes.dracula },
  },
};

export default config;