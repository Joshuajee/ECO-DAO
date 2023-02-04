import Layout from '@/components/ui/Layout';
import TopBanner from '@/components/ui/TopBanner';
import Head from 'next/head'


export default function Hackathons() {
  return (
    <Layout>
      <Head>
        <title> Hackathons </title>
      </Head>
      <TopBanner>
        Hey Hackers, go build amazing stuff
      </TopBanner>
    </Layout>
  )
}
