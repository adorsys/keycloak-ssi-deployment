import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docs: [
    {
      type: 'category',
      label: 'Keycloak SSI Deployment',
      link: {type: 'doc', id: 'index'},
      items: ['index'],
    },
  ],
};

export default sidebars;