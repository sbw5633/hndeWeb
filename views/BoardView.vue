<template>
  <div class="boardContainer">
    <h2>This is GeSiPan</h2>

    <!-- 게시판 헤더 -->
    <div class="boardHeader">
      <div class="headerItem" @click="sort('id')">
        <span v-if="sortField === 'id' && sortOrder === 'asc'">▲</span>
        <span v-else-if="sortField === 'id' && sortOrder === 'desc'">▼</span>
        순번
      </div>
      <div class="headerItem" style="cursor: default">제목</div>
      <div class="headerItem" @click="sort('deadline')">
        <span v-if="sortField === 'deadline' && sortOrder === 'asc'">▲</span>
        <span v-else-if="sortField === 'deadline' && sortOrder === 'desc'">▼</span>
        기한
      </div>
      <div class="headerItem" @click="sort('status')">
        <span v-if="sortField === 'status' && sortOrder === 'asc'">▲</span>
        <span v-else-if="sortField === 'status' && sortOrder === 'desc'">▼</span>
        제출여부
      </div>
    </div>

    <!-- 게시물 리스트 -->
    {{ isWritePage }}
    {{ router.currentRoute.value.path }}
    <router-view v-if="isWritePage" />
    <div v-else class="boardList">
      <div class="boardItem" v-for="item in paginatedItems" :key="item.id">
        <div class="boardItemField">{{ item.id }}</div>
        <div class="boardItemField">{{ item.title }}</div>
        <div class="boardItemField">{{ item.deadline }}</div>
        <div class="boardItemField">{{ item.status }}</div>
      </div>
    </div>

    <!-- 페이지네이션 및 글쓰기 버튼 컨테이너 -->
    <div class="paginationWrapper">
      <div class="pagination">
        <button class="pageButton" @click="prevPage" :disabled="currentPage === 1">이전</button>
        <span>{{ currentPage }} / {{ totalPages }}</span>
        <button class="pageButton" @click="nextPage" :disabled="currentPage === totalPages">
          다음
        </button>
      </div>
      <button class="writeButton" @click="writePost">글쓰기</button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import '@/css/BoardCss.css'

// 게시물 리스트 데이터
const boardItems = [
  { id: 1, title: '게시물 1', deadline: '2024-08-15', status: '제출 완료' },
  { id: 2, title: '게시물 2', deadline: '2024-08-20', status: '미제출' },
  { id: 3, title: '게시물 1', deadline: '2024-08-15', status: '제출 완료' },
  { id: 4, title: '게시물 2', deadline: '2024-08-20', status: '미제출' },
  { id: 5, title: '게시물 1', deadline: '2024-08-15', status: '제출 완료' },
  { id: 6, title: '게시물 2', deadline: '2024-08-20', status: '미제출' },
  { id: 7, title: '게시물 1', deadline: '2024-08-15', status: '제출 완료' },
  { id: 8, title: '게시물 2', deadline: '2024-08-20', status: '미제출' },
  { id: 9, title: '게시물 1', deadline: '2024-08-15', status: '제출 완료' },
  { id: 10, title: '게시물 2', deadline: '2024-08-20', status: '미제출' },
  { id: 11, title: '게시물 1', deadline: '2024-08-15', status: '제출 완료' },
  { id: 12, title: '게시물 2', deadline: '2024-08-20', status: '미제출' },
  { id: 13, title: '게시물 1', deadline: '2024-08-15', status: '제출 완료' },
  { id: 14, title: '게시물 2', deadline: '2024-08-20', status: '미제출' },
  { id: 15, title: '게시물 1', deadline: '2024-08-15', status: '제출 완료' },
  { id: 16, title: '게시물 2', deadline: '2024-08-20', status: '미제출' },
  { id: 17, title: '게시물 1', deadline: '2024-08-15', status: '제출 완료' },
  { id: 18, title: '게시물 2', deadline: '2024-08-20', status: '미제출' },
  { id: 19, title: '게시물 1', deadline: '2024-08-15', status: '제출 완료' },
  { id: 20, title: '게시물 2', deadline: '2024-08-20', status: '미제출' },
  { id: 21, title: '게시물 1', deadline: '2024-08-15', status: '제출 완료' },
  { id: 22, title: '게시물 2', deadline: '2024-08-20', status: '미제출' },
  { id: 23, title: '게시물 1', deadline: '2024-08-15', status: '제출 완료' },
  { id: 24, title: '게시물 2', deadline: '2024-08-20', status: '미제출' }
  // 추가적인 게시물 데이터...
]

import { useRouter } from 'vue-router'

// 라우터 가져오기
const router = useRouter()

const isWritePage = computed(() => router.currentRoute.value.path === '/board/write')

// 글쓰기 버튼 클릭 시 호출되는 함수
const writePost = () => {
  router.push('/board/write')
}

// 페이지네이션 관련 데이터
const itemsPerPage = 10
const currentPage = ref(1)
const totalPages = computed(() => Math.ceil(boardItems.length / itemsPerPage))

// 정렬 관련 데이터
const sortField = ref('id')
const sortOrder = ref('asc')

const paginatedItems = computed(() => {
  // 정렬
  const sortedItems = [...boardItems].sort((a, b) => {
    if (a[sortField.value] < b[sortField.value]) return sortOrder.value === 'asc' ? -1 : 1
    if (a[sortField.value] > b[sortField.value]) return sortOrder.value === 'asc' ? 1 : -1
    return 0
  })

  // 페이지네이션
  const start = (currentPage.value - 1) * itemsPerPage
  const end = start + itemsPerPage
  return sortedItems.slice(start, end)
})

const prevPage = () => {
  if (currentPage.value > 1) {
    currentPage.value--
  }
}

const nextPage = () => {
  if (currentPage.value < totalPages.value) {
    currentPage.value++
  }
}

const sort = (field) => {
  if (sortField.value === field) {
    // 현재 정렬 필드와 동일하면 정렬 방향 변경
    sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc'
  } else {
    // 새로운 필드로 정렬
    sortField.value = field
    sortOrder.value = 'asc'
  }
}
</script>
