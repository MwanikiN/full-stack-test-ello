import React, { useState, useEffect } from 'react';
import { ApolloProvider, ApolloClient, InMemoryCache, useQuery } from '@apollo/client';
import { gql } from 'graphql-tag';

import './App.css'
const client = new ApolloClient({
  uri: 'http://localhost:4000/graphql',
  cache: new InMemoryCache(),
});

const GET_BOOK = gql`
  query GetBook($title: String!) {
    getBook(title: $title) {
      title
      author
      pages {
        pageIndex
        content
        tokens {
          position
          value
        }
      }
    }
  }
`;

const bookTitles = [
  { value: "a_color_of_his_own", label: "A Color of His Own" },
  { value: "fishing_in_the_air", label: "Fishing in the Air" },
];

function App({ title }) {
  const [currentPages, setCurrentPages] = useState({ leftPage: 0, rightPage: 1 });
  const [currentToken, setCurrentToken] = useState(null);

  const { loading, error, data } = useQuery(GET_BOOK, {
    variables: { title },
  });

  useEffect(() => {
    if (data && data.getBook) {
      // Update title in the document title when data changes
      document.title = data.getBook.title;
    }
  }, [data]);

  if (loading) return <p>Loading...</p>;
  if (error) return <p>Error: {error.message}</p>;

  const book = data.getBook;
  if (!book) return <p>No book data available</p>;

  const pages = book.pages || [];

  const handlePageChange = (newLeftPage, newRightPage) => {
    setCurrentPages({ leftPage: newLeftPage, rightPage: newRightPage });
    setCurrentToken(null);
  };

  const handleTokenClick = (token) => {
    setCurrentToken(token);
  };

  return (
    <div className="App">
      <h1>{book.title}</h1>
      <div className="pages">
        <div className="page left-page">
          {pages[currentPages.leftPage] && <p>{pages[currentPages.leftPage].content}</p>}
        </div>
        <div className="page right-page">
          {pages[currentPages.rightPage] && <p>{pages[currentPages.rightPage].content}</p>}
        </div>
      </div>
      <div className="navigation">
        <button onClick={() => handlePageChange(currentPages.leftPage - 2, currentPages.rightPage - 2)}>Previous Page</button>
        <button onClick={() => handlePageChange(currentPages.leftPage + 2, currentPages.rightPage + 2)}>Next Page</button>
      </div>
      {currentToken && (
        <div className="token-view">
          <p>{currentToken.value}</p>
        </div>
      )}
      <div className="token-list">
        {pages[currentPages.leftPage] &&
          pages[currentPages.leftPage].tokens.map((token, index) => (
            <span key={index} onClick={() => handleTokenClick(token)}>
              {token.value}{' '}
            </span>
          ))}
        {pages[currentPages.rightPage] &&
          pages[currentPages.rightPage].tokens.map((token, index) => (
            <span key={index} onClick={() => handleTokenClick(token)}>
              {token.value}{' '}
            </span>
          ))}
      </div>
    </div>
  );
}

function Main() {
  const [currentBookTitle, setCurrentBookTitle] = useState(bookTitles[0].value);

  return (
    <ApolloProvider client={client}>
      <div className="select-container">
        <select className="select-dropdown" onChange={(e) => setCurrentBookTitle(e.target.value)}>
          {bookTitles.map((book) => (
            <option key={book.value} value={book.value}>
              {book.label}
            </option>
          ))}
        </select>
      </div>
      <App title={currentBookTitle} />
    </ApolloProvider>
  );
}

export default Main;
