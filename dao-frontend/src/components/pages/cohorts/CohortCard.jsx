import { useState } from "react"
import ModalWrapper from "@/components/ui/ModalWrapper"
import { links, routes } from "@/libs/routes"
import { useRouter } from "next/router"
import { AiOutlineClockCircle } from "react-icons/ai"
import EnrollmentForm from "./EnrollmentForm"
import CohortStatus from "./CohortStatus"
import { memo, useEffect } from "react"
import { useAccount, useContractRead } from "wagmi"
import { toast } from "react-toastify"
import CohortActions from "./CohortActions"
import CohortABI from '@/abi/contracts/Cohort.sol/Cohort.json';
import Badge from "@/components/ui/Badge"


const CohortCard = ({cohort, contract, expanded}) => {

    const { 
        name, commitment, size, status,
        startDate, endDate, description, contractAddress
    } = cohort

    const { isConnected, address } = useAccount()
    const [cohortStatus, setCohortStatus] = useState()
    const [startTime, setStartTime] = useState(0)
    const [deadline, setDeadline] = useState(0)
    const [currentTime, setCurrentTime] = useState(0)

    const router = useRouter()

    const [open, setOpen] = useState(false)

    const handleClick = () => {
        if (!isConnected) return toast.error("Please Connect")
        setOpen(true)
    } 

    const handleClose = () => {
        setOpen(false)
    } 

    const { data } = useContractRead({
        address: contract,
        abi: CohortABI,
        functionName: 'isStudent',
        args: [address],
        enabled: isConnected
    })

    console.log( deadline < currentTime )

    useEffect(() => {
        switch (status) {
            case 1:
                if (startTime < currentTime)
                    setCohortStatus({color: "blue", status: "Enrollment is open"})
                if (deadline > currentTime)
                    setCohortStatus({color: "green", status: "Cohort in session"})
                if (deadline < currentTime)
                    setCohortStatus({color: "yellow", status: "Cohort has ended"})
                break
            case 2:
                setCohortStatus({color: "green", status: "Successful"})
                break
            case 3:
                setCohortStatus({color: "gray", status: "Executed"})
                break
            default:
                setCohortStatus({color: "gray", status: "Enrollment not started"})
        }
    }, [status, startTime, deadline, currentTime]);

    useEffect(() => {
        setDeadline(Number(endDate.toString()))
    }, [endDate])

    useEffect(() => {
        setCurrentTime(Number(new Date()))
        const interval = setInterval(() => {
            setCurrentTime(Number(new Date()))
        }, 1000)
        return clearInterval(interval)
    }, [])

    return (
        <div className="text-gray-700 bg-white rounded-md p-4 md:px-4 shadow-lg w-full max-h-[500px] overflow-x-hidden overflow-y-auto">
            {/* <h3 className="mb-3 text-sm">COHORT ADDRESS: {cohort.contractAddress}</h3> */}
            <h2 className="text-black text-xl md:text-2xl font-semibold mb-3">{name}</h2>
            
            <p className="mb-3">{description}</p>
            
            <Badge color={cohortStatus?.color}> 
                <AiOutlineClockCircle size={18} /> 
                <p className="ml-2 text-sm">{cohortStatus?.status}</p> 
            </Badge>

            <div className="flex justify-end">
                <CohortStatus expanded={expanded} fee={commitment} students={size} start={startDate} end={endDate} />
            </div>

            <div className="flex justify-between">

                { !expanded ? <button onClick={() => router.push(`${links.cohorts}/${contractAddress}`)} className="text-gray-600">View Details </button> : <div> </div> }

                { (expanded && !data) && <button onClick={handleClick} className="bg-blue-600 hover:bg-blue-800 rounded-lg px-8 py-2 text-white"> Enroll </button> }

            </div>

            <ModalWrapper title={"Join Cohort"} open={open} handleClose={handleClose}>
                <EnrollmentForm cohort={cohort} contract={contract} close={handleClose} />
            </ModalWrapper>

            { expanded && <CohortActions status={status} contract={contract} isStudent={data} commitment={commitment.toString()} /> }
            
        </div>
    )
}

export default memo(CohortCard)