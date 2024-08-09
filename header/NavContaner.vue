<template>
  <header>
    <div class="navConts">
      <div class="logo">
        <img alt="HNDE logo" class="logo" src="@/assets/logo_hnde.png" />
      </div>

      <div class="wrapper">
        <nav>
          <RouterLink v-for="route in routes" :key="route.path" :to="route.path">{{
            route.name
          }}</RouterLink>
        </nav>
      </div>
    </div>
  </header>
</template>

<script>
import { routes } from '@/router/index.ts'

export default {
  data() {
    return {
      routes
    }
  }
}
</script>

<style scoped>
.navConts {
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto;
}

a {
  color: rgb(121, 121, 121);
  text-decoration-line: none;
}

header {
  line-height: 1.5;
  max-height: 100vh;
  /* background-color: rgb(55, 86, 114); */
}

.logo {
  max-height: 5vh;
  display: block;
}

nav {
  /* width: 100%; */
  font-size: 0.8rem;
  text-align: center;
}

nav a.router-link-exact-active {
  color: var(--color-text);
  font-size: larger;
}

nav a.router-link-exact-active:hover {
  background-color: transparent;
}

nav a {
  padding: 0 1rem;
  border-left: 1px solid rgb(226, 226, 226);
}

nav a:first-of-type {
  border: 0;
}

@media (min-width: 1024px) {
  header {
    display: flex;
    place-items: center;
    padding-right: calc(var(--section-gap) / 4);
  }

  .navConts {
    display: flex;
    align-items: center;
    margin: 0.1vw 1vw;
  }

  .logo {
    margin: 0 0 0 0;
  }

  header .wrapper {
    display: flex;
    place-items: flex-start;
    flex-wrap: wrap;
    /* background-color: aqua; */
  }

  nav {
    text-align: left;
    font-size: 1rem;
    margin: 0.5rem;
  }
}
</style>
