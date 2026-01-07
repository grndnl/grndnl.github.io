// get the ninja-keys element
const ninja = document.querySelector('ninja-keys');

// add the home and posts menu items
ninja.data = [{
    id: "nav-about",
    title: "about",
    section: "Navigation",
    handler: () => {
      window.location.href = "/";
    },
  },{id: "nav-publications",
          title: "publications",
          description: "Publications and patents. See Scholar for the most up-to-date list.",
          section: "Navigation",
          handler: () => {
            window.location.href = "/publications/";
          },
        },{id: "nav-projects",
          title: "projects",
          description: "A selection of projects. For the latest work see publications.",
          section: "Navigation",
          handler: () => {
            window.location.href = "/projects/";
          },
        },{id: "nav-repositories",
          title: "repositories",
          description: "Please refer to publications for a more comprehensive list of programming work.",
          section: "Navigation",
          handler: () => {
            window.location.href = "/repositories/";
          },
        },{id: "nav-resume",
          title: "resume",
          description: "A selection of my experience.",
          section: "Navigation",
          handler: () => {
            window.location.href = "/cv/";
          },
        },{id: "projects-f1-suspension",
          title: 'F1 Suspension',
          description: "Generative design of F1 suspension.",
          section: "Projects",handler: () => {
              window.location.href = "/projects/F1-wishbone.html";
            },},{id: "projects-generative-ai-for-assembly-design",
          title: 'Generative AI for Assembly Design',
          description: "How can Generative AI design tools be used to design assemblies, from coffee makers to EVs?",
          section: "Projects",handler: () => {
              window.location.href = "/projects/assembly-graph.html";
            },},{id: "projects-modular-chair",
          title: 'Modular chaiR',
          description: "Modular chair design for synthetic data generation and fabrication.",
          section: "Projects",handler: () => {
              window.location.href = "/projects/chair.html";
            },},{id: "projects-clean-data-is-all-you-need",
          title: '📄Clean data is all you need',
          description: "Process PDFs of scientific papers into structured data.",
          section: "Projects",handler: () => {
              window.location.href = "/projects/clean-data-is-all-you-need.html";
            },},{id: "projects-ai-assisted-knowledge-graph-design",
          title: 'AI-assisted Knowledge Graph Design',
          description: "Research collaboration with CSUN, NIST, and NASA JPL to implement a recommendation system for materials of part in assemblies.",
          section: "Projects",handler: () => {
              window.location.href = "/projects/csun.html";
            },},{id: "projects-dreamcatcher",
          title: 'Dreamcatcher',
          description: "Generative design research prototype, democratizing topology optimization.",
          section: "Projects",handler: () => {
              window.location.href = "/projects/dreamcatcher.html";
            },},{id: "projects-olsryd-9-cylinder-radial-engine",
          title: 'Olsryd 9 Cylinder Radial Engine',
          description: "Design of complete assembly of an airplane engine composed of more 1600 parts.",
          section: "Projects",handler: () => {
              window.location.href = "/projects/engine.html";
            },},{id: "projects-hackrod",
          title: 'Hackrod',
          description: "Generatively design manufacturable car chassis.",
          section: "Projects",handler: () => {
              window.location.href = "/projects/hackrod.html";
            },},{id: "projects-concept-interplanetary-lander",
          title: 'Concept Interplanetary Lander',
          description: "Research collaboration with NASA JPL leveraging generative design for space exploration.",
          section: "Projects",handler: () => {
              window.location.href = "/projects/lander.html";
            },},{id: "projects-6-dof-object-pose-estimation",
          title: '6 DoF object pose estimation',
          description: "Edge implementatinon of estimation from monocular 2D images.",
          section: "Projects",handler: () => {
              window.location.href = "/projects/object-pose-estimation.html";
            },},{id: "projects-generative-quadcopter",
          title: 'Generative Quadcopter',
          description: "Quadcopter chassis designed using generative design research prototype software.",
          section: "Projects",handler: () => {
              window.location.href = "/projects/quadcopter.html";
            },},{
        id: 'social-email',
        title: 'email',
        section: 'Socials',
        handler: () => {
          window.open("mailto:%67%6E%72%64%6E%6C@%67%6D%61%69%6C.%63%6F%6D", "_blank");
        },
      },{
        id: 'social-linkedin',
        title: 'LinkedIn',
        section: 'Socials',
        handler: () => {
          window.open("https://www.linkedin.com/in/grndnl", "_blank");
        },
      },{
        id: 'social-scholar',
        title: 'Google Scholar',
        section: 'Socials',
        handler: () => {
          window.open("https://scholar.google.com/citations?user=X0qp478AAAAJ&hl", "_blank");
        },
      },{
        id: 'social-work',
        title: 'Work',
        section: 'Socials',
        handler: () => {
          window.open("https://www.research.autodesk.com/people/daniele-grandi/", "_blank");
        },
      },{
      id: 'light-theme',
      title: 'Change theme to light',
      description: 'Change the theme of the site to Light',
      section: 'Theme',
      handler: () => {
        setThemeSetting("light");
      },
    },
    {
      id: 'dark-theme',
      title: 'Change theme to dark',
      description: 'Change the theme of the site to Dark',
      section: 'Theme',
      handler: () => {
        setThemeSetting("dark");
      },
    },
    {
      id: 'system-theme',
      title: 'Use system default theme',
      description: 'Change the theme of the site to System Default',
      section: 'Theme',
      handler: () => {
        setThemeSetting("system");
      },
    },];
