document.addEventListener('DOMContentLoaded', async function() {
 
  // GET method to retrieve the current visitor count and display it on the webpage
  async function getCurrentCount() {
    const response = await fetch('https://qeelt38opg.execute-api.us-east-1.amazonaws.com/prod/views');
    const data = await response.json();
    const count = data.views;
    const countElement = document.getElementById('views');
    countElement.innerText = count; 
  }

  getCurrentCount();
});